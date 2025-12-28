"""
Team Management API for PRSMTECH CRM
Enterprise-grade team, role, and member management endpoints.
"""

import frappe
from frappe import _
import json
from datetime import datetime


# ============================================================================
# TEAM MANAGEMENT
# ============================================================================

@frappe.whitelist()
def get_teams():
    """
    Get all teams with their details and member counts.
    """
    teams = frappe.db.sql("""
        SELECT
            t.id,
            t.name,
            t.description,
            t.manager_id,
            t.color,
            t.icon,
            t.avatar_url,
            t.capacity,
            t.current_workload,
            t.visibility,
            t.parent_team_id,
            t.is_active,
            t.created_at,
            t.updated_at,
            (
                SELECT COUNT(*)
                FROM prsm_frappuccino.team_members tm
                WHERE tm.team_id = t.id AND tm.is_active = true
            ) as member_count
        FROM prsm_frappuccino.teams t
        WHERE t.is_active = true
        ORDER BY t.name
    """, as_dict=True)

    return teams


@frappe.whitelist()
def get_team(team_id):
    """
    Get a single team with full details.
    """
    team = frappe.db.sql("""
        SELECT *
        FROM prsm_frappuccino.teams
        WHERE id = %s
    """, (team_id,), as_dict=True)

    if not team:
        frappe.throw(_("Team not found"))

    team = team[0]

    # Get team members
    team['members'] = get_team_members(team_id)

    return team


@frappe.whitelist()
def create_team(name, description=None, manager_id=None, color="#6366f1",
                icon="users", capacity=100, visibility="private", parent_team_id=None, tags=None):
    """
    Create a new team.
    """
    frappe.only_for(["System Manager", "Sales Manager"])

    team_id = frappe.generate_hash(length=32)

    frappe.db.sql("""
        INSERT INTO prsm_frappuccino.teams
        (id, name, description, manager_id, color, icon, capacity, visibility, parent_team_id, tags)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (team_id, name, description, manager_id, color, icon, capacity,
          visibility, parent_team_id, json.dumps(tags) if tags else None))

    frappe.db.commit()

    # If manager is set, add them as a team member with manager role
    if manager_id:
        add_team_member(team_id, manager_id, role="manager")

    return get_team(team_id)


@frappe.whitelist()
def update_team(team_id, **kwargs):
    """
    Update team details.
    """
    frappe.only_for(["System Manager", "Sales Manager"])

    allowed_fields = ['name', 'description', 'manager_id', 'color', 'icon',
                      'avatar_url', 'capacity', 'visibility', 'parent_team_id',
                      'tags', 'settings', 'is_active']

    update_parts = []
    values = []

    for field, value in kwargs.items():
        if field in allowed_fields:
            if field in ['tags', 'settings']:
                value = json.dumps(value) if value else None
            update_parts.append(f"{field} = %s")
            values.append(value)

    if not update_parts:
        frappe.throw(_("No valid fields to update"))

    values.append(team_id)

    frappe.db.sql(f"""
        UPDATE prsm_frappuccino.teams
        SET {', '.join(update_parts)}, updated_at = NOW()
        WHERE id = %s
    """, tuple(values))

    frappe.db.commit()

    return get_team(team_id)


@frappe.whitelist()
def delete_team(team_id):
    """
    Soft delete a team (sets is_active to false).
    """
    frappe.only_for(["System Manager"])

    frappe.db.sql("""
        UPDATE prsm_frappuccino.teams
        SET is_active = false, updated_at = NOW()
        WHERE id = %s
    """, (team_id,))

    frappe.db.commit()

    return {"success": True, "message": "Team deleted successfully"}


# ============================================================================
# TEAM MEMBER MANAGEMENT
# ============================================================================

@frappe.whitelist()
def get_team_members(team_id):
    """
    Get all members of a specific team.
    """
    members = frappe.db.sql("""
        SELECT
            tm.id,
            tm.team_id,
            tm.user_id,
            tm.role,
            tm.capacity_hours,
            tm.current_workload,
            tm.skills,
            tm.availability_status,
            tm.notes,
            tm.joined_at,
            tm.is_active,
            u.full_name as user_name,
            u.user_image as user_avatar,
            u.email as user_email
        FROM prsm_frappuccino.team_members tm
        LEFT JOIN tabUser u ON u.name = tm.user_id
        WHERE tm.team_id = %s AND tm.is_active = true
        ORDER BY tm.role DESC, u.full_name
    """, (team_id,), as_dict=True)

    return members


@frappe.whitelist()
def get_all_team_members():
    """
    Get all team memberships across all teams.
    """
    members = frappe.db.sql("""
        SELECT
            tm.id,
            tm.team_id,
            tm.user_id,
            tm.role,
            tm.capacity_hours,
            tm.current_workload,
            tm.availability_status,
            tm.is_active,
            t.name as team_name
        FROM prsm_frappuccino.team_members tm
        JOIN prsm_frappuccino.teams t ON t.id = tm.team_id
        WHERE tm.is_active = true AND t.is_active = true
    """, as_dict=True)

    return members


@frappe.whitelist()
def add_team_member(team_id, user_id, role="member", capacity_hours=40, skills=None, notes=None):
    """
    Add a user to a team.
    """
    frappe.only_for(["System Manager", "Sales Manager"])

    # Check if already a member
    existing = frappe.db.sql("""
        SELECT id FROM prsm_frappuccino.team_members
        WHERE team_id = %s AND user_id = %s AND is_active = true
    """, (team_id, user_id))

    if existing:
        frappe.throw(_("User is already a member of this team"))

    member_id = frappe.generate_hash(length=32)

    frappe.db.sql("""
        INSERT INTO prsm_frappuccino.team_members
        (id, team_id, user_id, role, capacity_hours, skills, notes)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (member_id, team_id, user_id, role, capacity_hours,
          json.dumps(skills) if skills else None, notes))

    frappe.db.commit()

    # Log activity
    log_team_activity(team_id, None, user_id, 'member_added',
                      'member', member_id, f"Added to team as {role}")

    return {
        "id": member_id,
        "team_id": team_id,
        "user_id": user_id,
        "role": role
    }


@frappe.whitelist()
def remove_team_member(team_id, user_id):
    """
    Remove a user from a team (soft delete).
    """
    frappe.only_for(["System Manager", "Sales Manager"])

    frappe.db.sql("""
        UPDATE prsm_frappuccino.team_members
        SET is_active = false, left_at = NOW()
        WHERE team_id = %s AND user_id = %s
    """, (team_id, user_id))

    frappe.db.commit()

    # Log activity
    log_team_activity(team_id, None, user_id, 'member_removed',
                      'member', None, "Removed from team")

    return {"success": True, "team_id": team_id, "user_id": user_id}


@frappe.whitelist()
def update_member_role(team_id, user_id, new_role):
    """
    Update a team member's role.
    """
    frappe.only_for(["System Manager", "Sales Manager"])

    allowed_roles = ['manager', 'member', 'lead', 'senior', 'contractor', 'viewer']

    if new_role not in allowed_roles:
        frappe.throw(_(f"Invalid role. Must be one of: {', '.join(allowed_roles)}"))

    frappe.db.sql("""
        UPDATE prsm_frappuccino.team_members
        SET role = %s
        WHERE team_id = %s AND user_id = %s AND is_active = true
    """, (new_role, team_id, user_id))

    frappe.db.commit()

    return {"success": True, "team_id": team_id, "user_id": user_id, "role": new_role}


@frappe.whitelist()
def update_member_availability(user_id, status, team_id=None):
    """
    Update a member's availability status.
    """
    allowed_statuses = ['available', 'busy', 'away', 'offline', 'dnd']

    if status not in allowed_statuses:
        frappe.throw(_(f"Invalid status. Must be one of: {', '.join(allowed_statuses)}"))

    if team_id:
        frappe.db.sql("""
            UPDATE prsm_frappuccino.team_members
            SET availability_status = %s
            WHERE user_id = %s AND team_id = %s AND is_active = true
        """, (status, user_id, team_id))
    else:
        frappe.db.sql("""
            UPDATE prsm_frappuccino.team_members
            SET availability_status = %s
            WHERE user_id = %s AND is_active = true
        """, (status, user_id))

    frappe.db.commit()

    return {"success": True, "user_id": user_id, "status": status}


# ============================================================================
# ROLE MANAGEMENT
# ============================================================================

@frappe.whitelist()
def get_roles():
    """
    Get all available roles.
    """
    roles = frappe.db.sql("""
        SELECT
            id,
            name,
            display_name,
            description,
            color,
            icon,
            permissions,
            is_system_role,
            hierarchy_level,
            is_active
        FROM prsm_frappuccino.roles
        WHERE is_active = true
        ORDER BY hierarchy_level DESC
    """, as_dict=True)

    return roles


@frappe.whitelist()
def get_user_roles(user_id, team_id=None):
    """
    Get all roles assigned to a user.
    """
    if team_id:
        roles = frappe.db.sql("""
            SELECT
                ur.id,
                ur.role_id,
                ur.team_id,
                ur.granted_at,
                ur.expires_at,
                r.name as role_name,
                r.display_name,
                r.hierarchy_level,
                r.permissions
            FROM prsm_frappuccino.user_roles ur
            JOIN prsm_frappuccino.roles r ON r.id = ur.role_id
            WHERE ur.user_id = %s AND ur.team_id = %s AND ur.is_active = true
            AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
        """, (user_id, team_id), as_dict=True)
    else:
        roles = frappe.db.sql("""
            SELECT
                ur.id,
                ur.role_id,
                ur.team_id,
                ur.granted_at,
                ur.expires_at,
                r.name as role_name,
                r.display_name,
                r.hierarchy_level,
                r.permissions,
                t.name as team_name
            FROM prsm_frappuccino.user_roles ur
            JOIN prsm_frappuccino.roles r ON r.id = ur.role_id
            LEFT JOIN prsm_frappuccino.teams t ON t.id = ur.team_id
            WHERE ur.user_id = %s AND ur.is_active = true
            AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
        """, (user_id,), as_dict=True)

    return roles


@frappe.whitelist()
def assign_role(user_id, role_id, team_id=None, expires_at=None):
    """
    Assign a role to a user.
    """
    frappe.only_for(["System Manager", "Sales Manager"])

    current_user = frappe.session.user

    # Check if already has this role
    existing = frappe.db.sql("""
        SELECT id FROM prsm_frappuccino.user_roles
        WHERE user_id = %s AND role_id = %s AND (team_id = %s OR (team_id IS NULL AND %s IS NULL))
        AND is_active = true
    """, (user_id, role_id, team_id, team_id))

    if existing:
        frappe.throw(_("User already has this role"))

    assignment_id = frappe.generate_hash(length=32)

    frappe.db.sql("""
        INSERT INTO prsm_frappuccino.user_roles
        (id, user_id, role_id, team_id, granted_by, expires_at)
        VALUES (%s, %s, %s, %s, %s, %s)
    """, (assignment_id, user_id, role_id, team_id, current_user, expires_at))

    frappe.db.commit()

    return {"id": assignment_id, "user_id": user_id, "role_id": role_id}


@frappe.whitelist()
def revoke_role(user_id, role_id, team_id=None):
    """
    Revoke a role from a user.
    """
    frappe.only_for(["System Manager", "Sales Manager"])

    if team_id:
        frappe.db.sql("""
            UPDATE prsm_frappuccino.user_roles
            SET is_active = false
            WHERE user_id = %s AND role_id = %s AND team_id = %s
        """, (user_id, role_id, team_id))
    else:
        frappe.db.sql("""
            UPDATE prsm_frappuccino.user_roles
            SET is_active = false
            WHERE user_id = %s AND role_id = %s AND team_id IS NULL
        """, (user_id, role_id))

    frappe.db.commit()

    return {"success": True}


# ============================================================================
# TEAM STATISTICS
# ============================================================================

@frappe.whitelist()
def get_team_stats(team_id):
    """
    Get team statistics and metrics.
    """
    stats = frappe.db.sql("""
        SELECT
            t.id,
            t.name,
            t.capacity,
            t.current_workload,
            (
                SELECT COUNT(*)
                FROM prsm_frappuccino.team_members tm
                WHERE tm.team_id = t.id AND tm.is_active = true
            ) as total_members,
            (
                SELECT COUNT(*)
                FROM prsm_frappuccino.team_members tm
                WHERE tm.team_id = t.id AND tm.is_active = true
                AND tm.availability_status = 'available'
            ) as available_members,
            (
                SELECT COUNT(*)
                FROM prsm_frappuccino.project_assignments pa
                WHERE pa.team_id = t.id AND pa.status = 'active'
            ) as active_assignments,
            (
                SELECT COUNT(*)
                FROM prsm_frappuccino.projects p
                WHERE p.team_id = t.id AND p.status = 'in_progress'
            ) as active_projects
        FROM prsm_frappuccino.teams t
        WHERE t.id = %s
    """, (team_id,), as_dict=True)

    if not stats:
        frappe.throw(_("Team not found"))

    stats = stats[0]

    # Calculate workload percentage
    if stats['capacity'] and stats['capacity'] > 0:
        stats['workload_percentage'] = round((stats['current_workload'] / stats['capacity']) * 100, 1)
    else:
        stats['workload_percentage'] = 0

    return stats


@frappe.whitelist()
def get_team_workload(team_id):
    """
    Get detailed workload information for a team.
    """
    members = frappe.db.sql("""
        SELECT
            tm.user_id,
            tm.capacity_hours,
            tm.current_workload,
            u.full_name,
            u.user_image,
            COALESCE(
                ROUND((tm.current_workload::float / NULLIF(tm.capacity_hours, 0)) * 100, 1),
                0
            ) as workload_percentage
        FROM prsm_frappuccino.team_members tm
        LEFT JOIN tabUser u ON u.name = tm.user_id
        WHERE tm.team_id = %s AND tm.is_active = true
        ORDER BY workload_percentage DESC
    """, (team_id,), as_dict=True)

    return members


# ============================================================================
# ACTIVITY LOGGING
# ============================================================================

def log_team_activity(team_id, project_id, user_id, activity_type,
                      entity_type, entity_id, description, metadata=None):
    """
    Log a team activity event.
    """
    activity_id = frappe.generate_hash(length=32)

    frappe.db.sql("""
        INSERT INTO prsm_frappuccino.team_activities
        (id, team_id, project_id, user_id, activity_type, entity_type,
         entity_id, description, metadata)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (activity_id, team_id, project_id, user_id, activity_type,
          entity_type, entity_id, description,
          json.dumps(metadata) if metadata else None))


@frappe.whitelist()
def get_team_activities(team_id, limit=50, offset=0):
    """
    Get recent team activities.
    """
    activities = frappe.db.sql("""
        SELECT
            ta.id,
            ta.activity_type,
            ta.entity_type,
            ta.entity_id,
            ta.title,
            ta.description,
            ta.metadata,
            ta.importance,
            ta.created_at,
            u.full_name as user_name,
            u.user_image as user_avatar,
            p.name as project_name
        FROM prsm_frappuccino.team_activities ta
        LEFT JOIN tabUser u ON u.name = ta.user_id
        LEFT JOIN prsm_frappuccino.projects p ON p.id = ta.project_id
        WHERE ta.team_id = %s
        ORDER BY ta.created_at DESC
        LIMIT %s OFFSET %s
    """, (team_id, limit, offset), as_dict=True)

    return activities
