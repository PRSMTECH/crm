import frappe
from frappe import _
from datetime import datetime, timedelta
import json


@frappe.whitelist()
def get_assignments(project_id=None, user_id=None, team_id=None, status=None, priority=None):
    """Get assignments with optional filters"""
    filters = []
    values = {}

    if project_id:
        filters.append("pa.project_id = %(project_id)s")
        values["project_id"] = project_id

    if user_id:
        filters.append("pa.user_id = %(user_id)s")
        values["user_id"] = user_id

    if team_id:
        filters.append("pa.team_id = %(team_id)s")
        values["team_id"] = team_id

    if status:
        filters.append("pa.status = %(status)s")
        values["status"] = status

    if priority is not None:
        filters.append("pa.priority = %(priority)s")
        values["priority"] = priority

    where_clause = " AND ".join(filters) if filters else "1=1"

    assignments = frappe.db.sql(
        f"""
        SELECT
            pa.id,
            pa.project_id,
            pa.user_id,
            pa.team_id,
            pa.role,
            pa.status,
            pa.priority,
            pa.start_date,
            pa.end_date,
            pa.estimated_hours,
            pa.actual_hours,
            pa.allocation_percentage,
            pa.notes,
            pa.created_at,
            pa.updated_at,
            u.full_name as user_name,
            u.user_image as user_image,
            t.name as team_name,
            p.name as project_name
        FROM project_assignments pa
        LEFT JOIN tabUser u ON pa.user_id = u.name
        LEFT JOIN teams t ON pa.team_id = t.id
        LEFT JOIN projects p ON pa.project_id = p.id
        WHERE {where_clause}
        ORDER BY pa.priority DESC, pa.created_at DESC
        """,
        values,
        as_dict=True
    )

    return assignments


@frappe.whitelist()
def get_assignment(assignment_id):
    """Get single assignment by ID"""
    assignment = frappe.db.sql(
        """
        SELECT
            pa.*,
            u.full_name as user_name,
            u.user_image as user_image,
            t.name as team_name,
            p.name as project_name
        FROM project_assignments pa
        LEFT JOIN tabUser u ON pa.user_id = u.name
        LEFT JOIN teams t ON pa.team_id = t.id
        LEFT JOIN projects p ON pa.project_id = p.id
        WHERE pa.id = %(assignment_id)s
        """,
        {"assignment_id": assignment_id},
        as_dict=True
    )

    if not assignment:
        frappe.throw(_("Assignment not found"))

    return assignment[0]


@frappe.whitelist()
def create_assignment(project_id, user_id, role="contributor", team_id=None, priority=1,
                      start_date=None, end_date=None, estimated_hours=None,
                      allocation_percentage=100, notes=None):
    """Create a new project assignment"""
    # Check if assignment already exists
    existing = frappe.db.sql(
        """
        SELECT id FROM project_assignments
        WHERE project_id = %(project_id)s AND user_id = %(user_id)s AND status != 'removed'
        """,
        {"project_id": project_id, "user_id": user_id},
        as_dict=True
    )

    if existing:
        frappe.throw(_("User is already assigned to this project"))

    assignment_id = frappe.generate_hash(length=10)

    frappe.db.sql(
        """
        INSERT INTO project_assignments
        (id, project_id, user_id, team_id, role, status, priority, start_date, end_date,
         estimated_hours, allocation_percentage, notes, assigned_by, created_at, updated_at)
        VALUES
        (%(id)s, %(project_id)s, %(user_id)s, %(team_id)s, %(role)s, 'active', %(priority)s,
         %(start_date)s, %(end_date)s, %(estimated_hours)s, %(allocation_percentage)s,
         %(notes)s, %(assigned_by)s, NOW(), NOW())
        """,
        {
            "id": assignment_id,
            "project_id": project_id,
            "user_id": user_id,
            "team_id": team_id,
            "role": role,
            "priority": priority,
            "start_date": start_date,
            "end_date": end_date,
            "estimated_hours": estimated_hours,
            "allocation_percentage": allocation_percentage,
            "notes": notes,
            "assigned_by": frappe.session.user
        }
    )

    frappe.db.commit()

    # Log activity
    log_assignment_activity(assignment_id, "created", f"Assigned {user_id} to project")

    return get_assignment(assignment_id)


@frappe.whitelist()
def update_assignment(assignment_id, **kwargs):
    """Update an existing assignment"""
    allowed_fields = [
        "role", "status", "priority", "start_date", "end_date",
        "estimated_hours", "actual_hours", "allocation_percentage", "notes"
    ]

    updates = []
    values = {"assignment_id": assignment_id}

    for field in allowed_fields:
        if field in kwargs and kwargs[field] is not None:
            updates.append(f"{field} = %({field})s")
            values[field] = kwargs[field]

    if not updates:
        frappe.throw(_("No fields to update"))

    updates.append("updated_at = NOW()")

    frappe.db.sql(
        f"""
        UPDATE project_assignments
        SET {", ".join(updates)}
        WHERE id = %(assignment_id)s
        """,
        values
    )

    frappe.db.commit()

    # Log activity
    log_assignment_activity(assignment_id, "updated", f"Updated assignment fields: {list(kwargs.keys())}")

    return get_assignment(assignment_id)


@frappe.whitelist()
def delete_assignment(assignment_id):
    """Soft delete an assignment by setting status to 'removed'"""
    frappe.db.sql(
        """
        UPDATE project_assignments
        SET status = 'removed', updated_at = NOW()
        WHERE id = %(assignment_id)s
        """,
        {"assignment_id": assignment_id}
    )

    frappe.db.commit()

    # Log activity
    log_assignment_activity(assignment_id, "removed", "Assignment removed")

    return {"success": True, "message": "Assignment removed"}


@frappe.whitelist()
def batch_assign(project_id, user_ids, role="contributor", team_id=None):
    """Assign multiple users to a project at once"""
    if isinstance(user_ids, str):
        user_ids = json.loads(user_ids)

    results = []
    for user_id in user_ids:
        try:
            assignment = create_assignment(
                project_id=project_id,
                user_id=user_id,
                role=role,
                team_id=team_id
            )
            results.append({"user_id": user_id, "success": True, "assignment": assignment})
        except Exception as e:
            results.append({"user_id": user_id, "success": False, "error": str(e)})

    return results


@frappe.whitelist()
def update_status(assignment_id, status):
    """Update assignment status"""
    valid_statuses = ["pending", "active", "completed", "on_hold", "removed"]
    if status not in valid_statuses:
        frappe.throw(_("Invalid status. Must be one of: {0}").format(", ".join(valid_statuses)))

    return update_assignment(assignment_id, status=status)


@frappe.whitelist()
def log_hours(assignment_id, hours, description=None):
    """Log hours worked on an assignment"""
    # Get current actual hours
    current = frappe.db.sql(
        """
        SELECT actual_hours FROM project_assignments WHERE id = %(assignment_id)s
        """,
        {"assignment_id": assignment_id},
        as_dict=True
    )

    if not current:
        frappe.throw(_("Assignment not found"))

    new_hours = (current[0].get("actual_hours") or 0) + float(hours)

    frappe.db.sql(
        """
        UPDATE project_assignments
        SET actual_hours = %(new_hours)s, updated_at = NOW()
        WHERE id = %(assignment_id)s
        """,
        {"assignment_id": assignment_id, "new_hours": new_hours}
    )

    frappe.db.commit()

    # Log activity
    log_assignment_activity(
        assignment_id,
        "hours_logged",
        f"Logged {hours} hours" + (f": {description}" if description else "")
    )

    return get_assignment(assignment_id)


@frappe.whitelist()
def get_user_workload(user_id, include_completed=False):
    """Get workload summary for a user"""
    status_filter = "AND pa.status IN ('active', 'pending')" if not include_completed else ""

    workload = frappe.db.sql(
        f"""
        SELECT
            COUNT(*) as total_assignments,
            SUM(CASE WHEN pa.status = 'active' THEN 1 ELSE 0 END) as active_assignments,
            SUM(COALESCE(pa.estimated_hours, 0)) as total_estimated_hours,
            SUM(COALESCE(pa.actual_hours, 0)) as total_actual_hours,
            SUM(COALESCE(pa.allocation_percentage, 0)) as total_allocation
        FROM project_assignments pa
        WHERE pa.user_id = %(user_id)s {status_filter}
        """,
        {"user_id": user_id},
        as_dict=True
    )

    # Get upcoming deadlines
    deadlines = frappe.db.sql(
        """
        SELECT
            pa.id,
            pa.project_id,
            p.name as project_name,
            pa.end_date,
            pa.priority
        FROM project_assignments pa
        LEFT JOIN projects p ON pa.project_id = p.id
        WHERE pa.user_id = %(user_id)s
        AND pa.status = 'active'
        AND pa.end_date IS NOT NULL
        AND pa.end_date <= DATE_ADD(NOW(), INTERVAL 7 DAY)
        ORDER BY pa.end_date ASC
        LIMIT 5
        """,
        {"user_id": user_id},
        as_dict=True
    )

    return {
        "summary": workload[0] if workload else {},
        "upcoming_deadlines": deadlines
    }


@frappe.whitelist()
def get_team_workload(team_id):
    """Get workload summary for a team"""
    workload = frappe.db.sql(
        """
        SELECT
            pa.user_id,
            u.full_name as user_name,
            u.user_image,
            COUNT(*) as total_assignments,
            SUM(CASE WHEN pa.status = 'active' THEN 1 ELSE 0 END) as active_assignments,
            SUM(COALESCE(pa.estimated_hours, 0)) as estimated_hours,
            SUM(COALESCE(pa.actual_hours, 0)) as actual_hours,
            SUM(COALESCE(pa.allocation_percentage, 0)) as total_allocation
        FROM project_assignments pa
        LEFT JOIN tabUser u ON pa.user_id = u.name
        WHERE pa.team_id = %(team_id)s AND pa.status IN ('active', 'pending')
        GROUP BY pa.user_id, u.full_name, u.user_image
        ORDER BY total_allocation DESC
        """,
        {"team_id": team_id},
        as_dict=True
    )

    return workload


@frappe.whitelist()
def get_project_team(project_id):
    """Get all team members assigned to a project"""
    team = frappe.db.sql(
        """
        SELECT
            pa.id as assignment_id,
            pa.user_id,
            u.full_name as user_name,
            u.user_image,
            pa.role,
            pa.status,
            pa.priority,
            pa.start_date,
            pa.end_date,
            pa.estimated_hours,
            pa.actual_hours,
            pa.allocation_percentage,
            t.name as team_name
        FROM project_assignments pa
        LEFT JOIN tabUser u ON pa.user_id = u.name
        LEFT JOIN teams t ON pa.team_id = t.id
        WHERE pa.project_id = %(project_id)s AND pa.status != 'removed'
        ORDER BY
            CASE pa.role
                WHEN 'owner' THEN 1
                WHEN 'manager' THEN 2
                WHEN 'lead' THEN 3
                ELSE 4
            END,
            pa.created_at ASC
        """,
        {"project_id": project_id},
        as_dict=True
    )

    return team


@frappe.whitelist()
def get_overdue_assignments(user_id=None, team_id=None):
    """Get overdue assignments"""
    filters = ["pa.status = 'active'", "pa.end_date < NOW()"]
    values = {}

    if user_id:
        filters.append("pa.user_id = %(user_id)s")
        values["user_id"] = user_id

    if team_id:
        filters.append("pa.team_id = %(team_id)s")
        values["team_id"] = team_id

    where_clause = " AND ".join(filters)

    overdue = frappe.db.sql(
        f"""
        SELECT
            pa.*,
            u.full_name as user_name,
            p.name as project_name,
            DATEDIFF(NOW(), pa.end_date) as days_overdue
        FROM project_assignments pa
        LEFT JOIN tabUser u ON pa.user_id = u.name
        LEFT JOIN projects p ON pa.project_id = p.id
        WHERE {where_clause}
        ORDER BY pa.priority DESC, days_overdue DESC
        """,
        values,
        as_dict=True
    )

    return overdue


def log_assignment_activity(assignment_id, action, details):
    """Log assignment activity to team_activities table"""
    try:
        # Get assignment info
        assignment = frappe.db.sql(
            """
            SELECT project_id, user_id, team_id FROM project_assignments WHERE id = %(id)s
            """,
            {"id": assignment_id},
            as_dict=True
        )

        if assignment:
            activity_id = frappe.generate_hash(length=10)
            frappe.db.sql(
                """
                INSERT INTO team_activities
                (id, team_id, user_id, activity_type, entity_type, entity_id, details, created_at)
                VALUES
                (%(id)s, %(team_id)s, %(user_id)s, %(action)s, 'assignment', %(entity_id)s, %(details)s, NOW())
                """,
                {
                    "id": activity_id,
                    "team_id": assignment[0].get("team_id"),
                    "user_id": frappe.session.user,
                    "action": action,
                    "entity_id": assignment_id,
                    "details": details
                }
            )
    except Exception:
        pass  # Don't fail if activity logging fails
