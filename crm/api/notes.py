import frappe
from frappe import _
import json
import re


@frappe.whitelist()
def get_project_notes(project_id, note_type=None, status=None, is_pinned=None, author_id=None):
    """Get notes for a project with optional filters"""
    filters = ["pn.project_id = %(project_id)s"]
    values = {"project_id": project_id}

    if note_type:
        filters.append("pn.note_type = %(note_type)s")
        values["note_type"] = note_type

    if status:
        filters.append("pn.status = %(status)s")
        values["status"] = status

    if is_pinned is not None:
        filters.append("pn.is_pinned = %(is_pinned)s")
        values["is_pinned"] = is_pinned

    if author_id:
        filters.append("pn.author_id = %(author_id)s")
        values["author_id"] = author_id

    where_clause = " AND ".join(filters)

    notes = frappe.db.sql(
        f"""
        SELECT
            pn.id,
            pn.project_id,
            pn.author_id,
            pn.title,
            pn.content,
            pn.note_type,
            pn.priority,
            pn.status,
            pn.is_pinned,
            pn.parent_id,
            pn.mentions,
            pn.attachments,
            pn.reactions,
            pn.resolved_by,
            pn.resolved_at,
            pn.created_at,
            pn.updated_at,
            u.full_name as author_name,
            u.user_image as author_image,
            (SELECT COUNT(*) FROM project_notes WHERE parent_id = pn.id) as thread_count
        FROM project_notes pn
        LEFT JOIN tabUser u ON pn.author_id = u.name
        WHERE {where_clause} AND pn.parent_id IS NULL
        ORDER BY pn.is_pinned DESC, pn.created_at DESC
        """,
        values,
        as_dict=True
    )

    # Get read status for current user
    current_user = frappe.session.user
    for note in notes:
        read_status = frappe.db.sql(
            """
            SELECT user_id FROM note_read_receipts WHERE note_id = %(note_id)s AND user_id = %(user_id)s
            """,
            {"note_id": note["id"], "user_id": current_user},
            as_dict=True
        )
        note["is_read"] = len(read_status) > 0

        # Parse JSON fields
        if note.get("mentions"):
            note["mentions"] = json.loads(note["mentions"]) if isinstance(note["mentions"], str) else note["mentions"]
        if note.get("attachments"):
            note["attachments"] = json.loads(note["attachments"]) if isinstance(note["attachments"], str) else note["attachments"]
        if note.get("reactions"):
            note["reactions"] = json.loads(note["reactions"]) if isinstance(note["reactions"], str) else note["reactions"]

    return notes


@frappe.whitelist()
def get_note(note_id):
    """Get a single note by ID with full details"""
    note = frappe.db.sql(
        """
        SELECT
            pn.*,
            u.full_name as author_name,
            u.user_image as author_image,
            ru.full_name as resolved_by_name
        FROM project_notes pn
        LEFT JOIN tabUser u ON pn.author_id = u.name
        LEFT JOIN tabUser ru ON pn.resolved_by = ru.name
        WHERE pn.id = %(note_id)s
        """,
        {"note_id": note_id},
        as_dict=True
    )

    if not note:
        frappe.throw(_("Note not found"))

    note = note[0]

    # Parse JSON fields
    for field in ["mentions", "attachments", "reactions"]:
        if note.get(field):
            note[field] = json.loads(note[field]) if isinstance(note[field], str) else note[field]

    # Get thread replies
    note["replies"] = get_note_replies(note_id)

    # Get read receipts
    note["read_by"] = frappe.db.sql(
        """
        SELECT user_id, read_at FROM note_read_receipts WHERE note_id = %(note_id)s
        """,
        {"note_id": note_id},
        as_dict=True
    )

    return note


@frappe.whitelist()
def create_project_note(project_id, content, title=None, note_type="general",
                        priority="normal", mentions=None, attachments=None):
    """Create a new project note"""
    note_id = frappe.generate_hash(length=10)

    # Parse mentions from content if not provided
    if mentions is None:
        mentions = extract_mentions(content)

    frappe.db.sql(
        """
        INSERT INTO project_notes
        (id, project_id, author_id, title, content, note_type, priority, status,
         is_pinned, mentions, attachments, created_at, updated_at)
        VALUES
        (%(id)s, %(project_id)s, %(author_id)s, %(title)s, %(content)s, %(note_type)s,
         %(priority)s, 'open', FALSE, %(mentions)s, %(attachments)s, NOW(), NOW())
        """,
        {
            "id": note_id,
            "project_id": project_id,
            "author_id": frappe.session.user,
            "title": title,
            "content": content,
            "note_type": note_type,
            "priority": priority,
            "mentions": json.dumps(mentions) if mentions else None,
            "attachments": json.dumps(attachments) if attachments else None
        }
    )

    frappe.db.commit()

    # Send notifications to mentioned users
    if mentions:
        send_mention_notifications(note_id, mentions, project_id)

    return get_note(note_id)


@frappe.whitelist()
def update_project_note(note_id, **kwargs):
    """Update an existing note"""
    allowed_fields = ["title", "content", "note_type", "priority", "status", "attachments"]

    updates = []
    values = {"note_id": note_id}

    for field in allowed_fields:
        if field in kwargs and kwargs[field] is not None:
            if field in ["attachments"]:
                values[field] = json.dumps(kwargs[field]) if not isinstance(kwargs[field], str) else kwargs[field]
            else:
                values[field] = kwargs[field]
            updates.append(f"{field} = %({field})s")

    # Re-extract mentions if content changed
    if "content" in kwargs:
        mentions = extract_mentions(kwargs["content"])
        values["mentions"] = json.dumps(mentions) if mentions else None
        updates.append("mentions = %(mentions)s")

    if not updates:
        frappe.throw(_("No fields to update"))

    updates.append("updated_at = NOW()")

    frappe.db.sql(
        f"""
        UPDATE project_notes
        SET {", ".join(updates)}
        WHERE id = %(note_id)s
        """,
        values
    )

    frappe.db.commit()

    return get_note(note_id)


@frappe.whitelist()
def delete_project_note(note_id):
    """Delete a note and its replies"""
    # Delete replies first
    frappe.db.sql(
        """
        DELETE FROM project_notes WHERE parent_id = %(note_id)s
        """,
        {"note_id": note_id}
    )

    # Delete read receipts
    frappe.db.sql(
        """
        DELETE FROM note_read_receipts WHERE note_id = %(note_id)s
        """,
        {"note_id": note_id}
    )

    # Delete the note
    frappe.db.sql(
        """
        DELETE FROM project_notes WHERE id = %(note_id)s
        """,
        {"note_id": note_id}
    )

    frappe.db.commit()

    return {"success": True, "message": "Note deleted"}


@frappe.whitelist()
def reply_to_note(parent_id, content, mentions=None):
    """Create a reply to an existing note"""
    # Get parent note's project_id
    parent = frappe.db.sql(
        """
        SELECT project_id FROM project_notes WHERE id = %(parent_id)s
        """,
        {"parent_id": parent_id},
        as_dict=True
    )

    if not parent:
        frappe.throw(_("Parent note not found"))

    reply_id = frappe.generate_hash(length=10)

    # Parse mentions from content if not provided
    if mentions is None:
        mentions = extract_mentions(content)

    frappe.db.sql(
        """
        INSERT INTO project_notes
        (id, project_id, author_id, content, note_type, priority, status,
         is_pinned, parent_id, mentions, created_at, updated_at)
        VALUES
        (%(id)s, %(project_id)s, %(author_id)s, %(content)s, 'general', 'normal',
         'open', FALSE, %(parent_id)s, %(mentions)s, NOW(), NOW())
        """,
        {
            "id": reply_id,
            "project_id": parent[0]["project_id"],
            "author_id": frappe.session.user,
            "content": content,
            "parent_id": parent_id,
            "mentions": json.dumps(mentions) if mentions else None
        }
    )

    frappe.db.commit()

    # Send notifications
    if mentions:
        send_mention_notifications(reply_id, mentions, parent[0]["project_id"])

    return get_note(reply_id)


@frappe.whitelist()
def get_note_replies(note_id):
    """Get all replies to a note"""
    replies = frappe.db.sql(
        """
        SELECT
            pn.id,
            pn.author_id,
            pn.content,
            pn.mentions,
            pn.reactions,
            pn.created_at,
            pn.updated_at,
            u.full_name as author_name,
            u.user_image as author_image
        FROM project_notes pn
        LEFT JOIN tabUser u ON pn.author_id = u.name
        WHERE pn.parent_id = %(note_id)s
        ORDER BY pn.created_at ASC
        """,
        {"note_id": note_id},
        as_dict=True
    )

    for reply in replies:
        if reply.get("mentions"):
            reply["mentions"] = json.loads(reply["mentions"]) if isinstance(reply["mentions"], str) else reply["mentions"]
        if reply.get("reactions"):
            reply["reactions"] = json.loads(reply["reactions"]) if isinstance(reply["reactions"], str) else reply["reactions"]

    return replies


@frappe.whitelist()
def toggle_pin(note_id):
    """Toggle pin status of a note"""
    current = frappe.db.sql(
        """
        SELECT is_pinned FROM project_notes WHERE id = %(note_id)s
        """,
        {"note_id": note_id},
        as_dict=True
    )

    if not current:
        frappe.throw(_("Note not found"))

    new_status = not current[0]["is_pinned"]

    frappe.db.sql(
        """
        UPDATE project_notes SET is_pinned = %(is_pinned)s, updated_at = NOW() WHERE id = %(note_id)s
        """,
        {"note_id": note_id, "is_pinned": new_status}
    )

    frappe.db.commit()

    return {"id": note_id, "is_pinned": new_status}


@frappe.whitelist()
def resolve_note(note_id):
    """Mark a note as resolved"""
    frappe.db.sql(
        """
        UPDATE project_notes
        SET status = 'resolved', resolved_by = %(user)s, resolved_at = NOW(), updated_at = NOW()
        WHERE id = %(note_id)s
        """,
        {"note_id": note_id, "user": frappe.session.user}
    )

    frappe.db.commit()

    return get_note(note_id)


@frappe.whitelist()
def add_reaction(note_id, emoji):
    """Add a reaction to a note"""
    current = frappe.db.sql(
        """
        SELECT reactions FROM project_notes WHERE id = %(note_id)s
        """,
        {"note_id": note_id},
        as_dict=True
    )

    if not current:
        frappe.throw(_("Note not found"))

    reactions = current[0].get("reactions")
    if reactions:
        reactions = json.loads(reactions) if isinstance(reactions, str) else reactions
    else:
        reactions = {}

    user = frappe.session.user

    # Initialize emoji entry if not exists
    if emoji not in reactions:
        reactions[emoji] = []

    # Toggle reaction
    if user in reactions[emoji]:
        reactions[emoji].remove(user)
        if not reactions[emoji]:
            del reactions[emoji]
    else:
        reactions[emoji].append(user)

    frappe.db.sql(
        """
        UPDATE project_notes SET reactions = %(reactions)s, updated_at = NOW() WHERE id = %(note_id)s
        """,
        {"note_id": note_id, "reactions": json.dumps(reactions)}
    )

    frappe.db.commit()

    return {"note_id": note_id, "reactions": reactions}


@frappe.whitelist()
def mark_as_read(note_id):
    """Mark a note as read by the current user"""
    user = frappe.session.user

    # Check if already read
    existing = frappe.db.sql(
        """
        SELECT id FROM note_read_receipts WHERE note_id = %(note_id)s AND user_id = %(user_id)s
        """,
        {"note_id": note_id, "user_id": user},
        as_dict=True
    )

    if not existing:
        receipt_id = frappe.generate_hash(length=10)
        frappe.db.sql(
            """
            INSERT INTO note_read_receipts (id, note_id, user_id, read_at)
            VALUES (%(id)s, %(note_id)s, %(user_id)s, NOW())
            """,
            {"id": receipt_id, "note_id": note_id, "user_id": user}
        )
        frappe.db.commit()

    return {"note_id": note_id, "user_id": user}


@frappe.whitelist()
def get_unread_notes(project_id=None):
    """Get unread notes for the current user"""
    user = frappe.session.user

    project_filter = "AND pn.project_id = %(project_id)s" if project_id else ""
    values = {"user_id": user}
    if project_id:
        values["project_id"] = project_id

    unread = frappe.db.sql(
        f"""
        SELECT
            pn.id,
            pn.project_id,
            pn.title,
            pn.note_type,
            pn.priority,
            pn.author_id,
            pn.created_at,
            u.full_name as author_name,
            p.name as project_name
        FROM project_notes pn
        LEFT JOIN tabUser u ON pn.author_id = u.name
        LEFT JOIN projects p ON pn.project_id = p.id
        WHERE pn.parent_id IS NULL
        AND pn.id NOT IN (SELECT note_id FROM note_read_receipts WHERE user_id = %(user_id)s)
        {project_filter}
        ORDER BY pn.created_at DESC
        """,
        values,
        as_dict=True
    )

    return unread


@frappe.whitelist()
def get_mentioned_notes(user_id=None):
    """Get notes where user is mentioned"""
    user = user_id or frappe.session.user

    notes = frappe.db.sql(
        """
        SELECT
            pn.id,
            pn.project_id,
            pn.title,
            pn.content,
            pn.note_type,
            pn.priority,
            pn.author_id,
            pn.created_at,
            u.full_name as author_name,
            p.name as project_name
        FROM project_notes pn
        LEFT JOIN tabUser u ON pn.author_id = u.name
        LEFT JOIN projects p ON pn.project_id = p.id
        WHERE pn.mentions LIKE %(pattern)s
        ORDER BY pn.created_at DESC
        LIMIT 50
        """,
        {"pattern": f'%"{user}"%'},
        as_dict=True
    )

    return notes


def extract_mentions(content):
    """Extract @mentions from content using the format @[Name](user_id)"""
    if not content:
        return []

    # Pattern matches @[Name](user_id)
    pattern = r'@\[([^\]]+)\]\(([^)]+)\)'
    matches = re.findall(pattern, content)

    return [{"name": m[0], "id": m[1]} for m in matches]


def send_mention_notifications(note_id, mentions, project_id):
    """Send notifications to mentioned users"""
    try:
        note = frappe.db.sql(
            """
            SELECT author_id, content FROM project_notes WHERE id = %(note_id)s
            """,
            {"note_id": note_id},
            as_dict=True
        )

        if not note:
            return

        author = note[0]["author_id"]
        content_preview = note[0]["content"][:100] if note[0]["content"] else ""

        for mention in mentions:
            user_id = mention.get("id")
            if user_id and user_id != author:
                notification_id = frappe.generate_hash(length=10)
                frappe.db.sql(
                    """
                    INSERT INTO team_notifications
                    (id, user_id, type, title, message, entity_type, entity_id, created_at)
                    VALUES
                    (%(id)s, %(user_id)s, 'mention', %(title)s, %(message)s, 'note', %(entity_id)s, NOW())
                    """,
                    {
                        "id": notification_id,
                        "user_id": user_id,
                        "title": f"You were mentioned by {author}",
                        "message": content_preview,
                        "entity_id": note_id
                    }
                )

        frappe.db.commit()
    except Exception:
        pass  # Don't fail if notification sending fails
