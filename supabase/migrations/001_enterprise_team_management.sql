-- ============================================================================
-- ENTERPRISE TEAM MANAGEMENT MIGRATION
-- ============================================================================
-- Extends the existing schema with enterprise-grade team management features:
-- - Enhanced roles system with permissions
-- - Project assignments with team collaboration
-- - Rich project notes with @mentions and threading
-- - Team workload and capacity tracking
-- ============================================================================

-- ============================================================================
-- ENHANCED ROLES & PERMISSIONS
-- ============================================================================

-- Role Definitions with granular permissions
CREATE TABLE IF NOT EXISTS prsm_frappuccino.roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  description TEXT,
  color VARCHAR(7) DEFAULT '#6366f1',
  icon VARCHAR(50) DEFAULT 'user',
  permissions JSONB DEFAULT '{}',
  is_system_role BOOLEAN DEFAULT false, -- Cannot be deleted
  hierarchy_level INTEGER DEFAULT 0, -- Higher = more authority
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default enterprise roles
INSERT INTO prsm_frappuccino.roles (name, display_name, description, color, icon, permissions, is_system_role, hierarchy_level) VALUES
  ('admin', 'Administrator', 'Full system access with all permissions', '#dc2626', 'shield',
   '{"all": true}', true, 100),
  ('manager', 'Team Manager', 'Can manage teams, assign work, and view reports', '#f59e0b', 'users',
   '{"teams": {"create": true, "edit": true, "delete": true, "view": true}, "assignments": {"create": true, "edit": true, "delete": true, "view": true}, "reports": {"view": true}, "members": {"add": true, "remove": true, "edit_role": true}}', true, 80),
  ('lead', 'Team Lead', 'Can lead projects and assign tasks within their team', '#3b82f6', 'star',
   '{"teams": {"view": true}, "assignments": {"create": true, "edit": true, "view": true}, "tasks": {"create": true, "edit": true, "delete": true, "view": true}}', true, 60),
  ('senior', 'Senior Member', 'Experienced member with mentoring capabilities', '#8b5cf6', 'award',
   '{"assignments": {"view": true, "edit_own": true}, "tasks": {"create": true, "edit_own": true, "view": true}, "mentoring": {"assign": true}}', true, 40),
  ('member', 'Team Member', 'Standard team member with basic access', '#22c55e', 'user',
   '{"assignments": {"view_own": true}, "tasks": {"view_own": true, "edit_own": true}}', true, 20),
  ('contractor', 'Contractor', 'External contractor with limited access', '#6b7280', 'briefcase',
   '{"assignments": {"view_assigned": true}, "tasks": {"view_assigned": true, "edit_assigned": true}}', true, 10),
  ('viewer', 'Viewer', 'Read-only access to assigned projects', '#9ca3af', 'eye',
   '{"projects": {"view_assigned": true}, "reports": {"view_limited": true}}', true, 5)
ON CONFLICT (name) DO NOTHING;

-- User role assignments (allows multiple roles per user)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  role_id UUID REFERENCES prsm_frappuccino.roles(id) ON DELETE CASCADE,
  team_id UUID REFERENCES prsm_frappuccino.teams(id) ON DELETE CASCADE, -- NULL = global role
  granted_by UUID,
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  UNIQUE(user_id, role_id, team_id)
);

-- ============================================================================
-- ENHANCED TEAM FEATURES
-- ============================================================================

-- Add new columns to existing teams table
ALTER TABLE prsm_frappuccino.teams ADD COLUMN IF NOT EXISTS
  icon VARCHAR(50) DEFAULT 'users';
ALTER TABLE prsm_frappuccino.teams ADD COLUMN IF NOT EXISTS
  avatar_url TEXT;
ALTER TABLE prsm_frappuccino.teams ADD COLUMN IF NOT EXISTS
  capacity INTEGER DEFAULT 100; -- Team workload capacity (hours/week)
ALTER TABLE prsm_frappuccino.teams ADD COLUMN IF NOT EXISTS
  current_workload INTEGER DEFAULT 0; -- Current assigned hours
ALTER TABLE prsm_frappuccino.teams ADD COLUMN IF NOT EXISTS
  settings JSONB DEFAULT '{}'; -- Team-specific settings
ALTER TABLE prsm_frappuccino.teams ADD COLUMN IF NOT EXISTS
  tags TEXT[];
ALTER TABLE prsm_frappuccino.teams ADD COLUMN IF NOT EXISTS
  parent_team_id UUID REFERENCES prsm_frappuccino.teams(id); -- For nested teams
ALTER TABLE prsm_frappuccino.teams ADD COLUMN IF NOT EXISTS
  visibility VARCHAR(20) DEFAULT 'private'; -- 'public', 'private', 'secret'

-- Enhanced team members with capacity tracking
ALTER TABLE prsm_frappuccino.team_members ADD COLUMN IF NOT EXISTS
  capacity_hours INTEGER DEFAULT 40; -- Weekly capacity in hours
ALTER TABLE prsm_frappuccino.team_members ADD COLUMN IF NOT EXISTS
  current_workload INTEGER DEFAULT 0; -- Current assigned hours
ALTER TABLE prsm_frappuccino.team_members ADD COLUMN IF NOT EXISTS
  skills TEXT[];
ALTER TABLE prsm_frappuccino.team_members ADD COLUMN IF NOT EXISTS
  availability_status VARCHAR(50) DEFAULT 'available'; -- 'available', 'busy', 'away', 'offline'
ALTER TABLE prsm_frappuccino.team_members ADD COLUMN IF NOT EXISTS
  notes TEXT;

-- ============================================================================
-- PROJECT ASSIGNMENTS SYSTEM
-- ============================================================================

-- Project Categories
CREATE TABLE IF NOT EXISTS prsm_frappuccino.project_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  color VARCHAR(7) DEFAULT '#3b82f6',
  icon VARCHAR(50) DEFAULT 'folder',
  parent_id UUID REFERENCES prsm_frappuccino.project_categories(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Project Assignments (who's assigned to what project/task)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.project_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES prsm_frappuccino.projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  team_id UUID REFERENCES prsm_frappuccino.teams(id),
  role VARCHAR(100) DEFAULT 'contributor', -- 'owner', 'manager', 'contributor', 'reviewer', 'viewer'
  responsibility TEXT, -- What they're responsible for
  estimated_hours INTEGER,
  actual_hours INTEGER DEFAULT 0,
  start_date DATE,
  end_date DATE,
  status VARCHAR(50) DEFAULT 'active', -- 'pending', 'active', 'completed', 'on_hold', 'removed'
  priority INTEGER DEFAULT 0, -- 0=low, 1=medium, 2=high, 3=urgent
  allocation_percentage INTEGER DEFAULT 100, -- % of time allocated to this project
  assigned_by UUID,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  notes TEXT,
  custom_fields JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Task Assignments (for individual tasks within projects)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES prsm_frappuccino.tasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  role VARCHAR(50) DEFAULT 'assignee', -- 'assignee', 'reviewer', 'watcher'
  assigned_by UUID,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  due_date TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  notes TEXT,
  is_active BOOLEAN DEFAULT true
);

-- ============================================================================
-- RICH PROJECT NOTES SYSTEM
-- ============================================================================

-- Project Notes with threading and @mentions
CREATE TABLE IF NOT EXISTS prsm_frappuccino.project_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES prsm_frappuccino.projects(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES prsm_frappuccino.project_notes(id) ON DELETE CASCADE, -- For threaded replies
  author_id UUID NOT NULL,
  title VARCHAR(255),
  content TEXT NOT NULL,
  content_html TEXT, -- Rich text HTML version
  note_type VARCHAR(50) DEFAULT 'general', -- 'general', 'update', 'blocker', 'decision', 'milestone', 'question', 'announcement'
  priority VARCHAR(20) DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
  status VARCHAR(50) DEFAULT 'open', -- 'open', 'resolved', 'archived'
  mentions UUID[], -- Users mentioned
  mentioned_teams UUID[], -- Teams mentioned
  tags TEXT[],
  attachments JSONB DEFAULT '[]', -- [{name, url, size, type}]
  reactions JSONB DEFAULT '{}', -- {emoji: [user_ids]}
  is_pinned BOOLEAN DEFAULT false,
  is_private BOOLEAN DEFAULT false, -- Only visible to mentioned users/teams
  visibility VARCHAR(20) DEFAULT 'team', -- 'public', 'team', 'private', 'mentioned_only'
  read_by UUID[] DEFAULT '{}',
  resolved_by UUID,
  resolved_at TIMESTAMPTZ,
  edited_at TIMESTAMPTZ,
  thread_count INTEGER DEFAULT 0, -- Number of replies
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Note read receipts
CREATE TABLE IF NOT EXISTS prsm_frappuccino.note_read_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID REFERENCES prsm_frappuccino.project_notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  read_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(note_id, user_id)
);

-- ============================================================================
-- UPCOMING PROJECTS TRACKING
-- ============================================================================

-- Enhanced projects with more enterprise features
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  category_id UUID REFERENCES prsm_frappuccino.project_categories(id);
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  visibility VARCHAR(20) DEFAULT 'team'; -- 'public', 'team', 'private'
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  project_type VARCHAR(50) DEFAULT 'internal'; -- 'internal', 'client', 'research', 'maintenance'
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  risk_level VARCHAR(20) DEFAULT 'low'; -- 'low', 'medium', 'high', 'critical'
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  complexity VARCHAR(20) DEFAULT 'medium'; -- 'simple', 'medium', 'complex', 'enterprise'
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  estimated_hours INTEGER;
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  actual_hours INTEGER DEFAULT 0;
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  stakeholders UUID[];
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  watchers UUID[];
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  external_links JSONB DEFAULT '[]'; -- [{title, url, type}]
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  requirements JSONB DEFAULT '[]'; -- [{id, text, status, priority}]
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  objectives TEXT[];
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  key_deliverables TEXT[];
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  kickoff_date DATE;
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  review_date DATE;
ALTER TABLE prsm_frappuccino.projects ADD COLUMN IF NOT EXISTS
  last_activity_at TIMESTAMPTZ;

-- Project Templates for quick setup
CREATE TABLE IF NOT EXISTS prsm_frappuccino.project_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  category_id UUID REFERENCES prsm_frappuccino.project_categories(id),
  default_status VARCHAR(50) DEFAULT 'planning',
  default_priority VARCHAR(20) DEFAULT 'medium',
  estimated_duration_days INTEGER,
  default_milestones JSONB DEFAULT '[]', -- [{name, offset_days, description}]
  default_tasks JSONB DEFAULT '[]', -- [{title, description, offset_days, assignee_role}]
  default_team_roles JSONB DEFAULT '[]', -- [{role, count, skills_required}]
  checklist JSONB DEFAULT '[]', -- [{text, required}]
  tags TEXT[],
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TEAM ACTIVITY & NOTIFICATIONS
-- ============================================================================

-- Team Activity Feed
CREATE TABLE IF NOT EXISTS prsm_frappuccino.team_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES prsm_frappuccino.teams(id) ON DELETE CASCADE,
  project_id UUID REFERENCES prsm_frappuccino.projects(id) ON DELETE SET NULL,
  user_id UUID NOT NULL,
  activity_type VARCHAR(100) NOT NULL, -- 'assignment_created', 'note_added', 'milestone_completed', etc.
  entity_type VARCHAR(50), -- 'project', 'task', 'note', 'member'
  entity_id UUID,
  title VARCHAR(255),
  description TEXT,
  metadata JSONB DEFAULT '{}',
  importance VARCHAR(20) DEFAULT 'normal', -- 'low', 'normal', 'high', 'critical'
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Team Notifications
CREATE TABLE IF NOT EXISTS prsm_frappuccino.team_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  team_id UUID REFERENCES prsm_frappuccino.teams(id) ON DELETE CASCADE,
  notification_type VARCHAR(100) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT,
  action_url TEXT,
  entity_type VARCHAR(50),
  entity_id UUID,
  sender_id UUID,
  is_read BOOLEAN DEFAULT false,
  is_dismissed BOOLEAN DEFAULT false,
  priority VARCHAR(20) DEFAULT 'normal',
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Roles
CREATE INDEX IF NOT EXISTS idx_roles_hierarchy ON prsm_frappuccino.roles(hierarchy_level DESC);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON prsm_frappuccino.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_team ON prsm_frappuccino.user_roles(team_id);

-- Assignments
CREATE INDEX IF NOT EXISTS idx_project_assignments_project ON prsm_frappuccino.project_assignments(project_id);
CREATE INDEX IF NOT EXISTS idx_project_assignments_user ON prsm_frappuccino.project_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_project_assignments_team ON prsm_frappuccino.project_assignments(team_id);
CREATE INDEX IF NOT EXISTS idx_project_assignments_status ON prsm_frappuccino.project_assignments(status);
CREATE INDEX IF NOT EXISTS idx_task_assignments_task ON prsm_frappuccino.task_assignments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_user ON prsm_frappuccino.task_assignments(user_id);

-- Notes
CREATE INDEX IF NOT EXISTS idx_project_notes_project ON prsm_frappuccino.project_notes(project_id);
CREATE INDEX IF NOT EXISTS idx_project_notes_author ON prsm_frappuccino.project_notes(author_id);
CREATE INDEX IF NOT EXISTS idx_project_notes_parent ON prsm_frappuccino.project_notes(parent_id);
CREATE INDEX IF NOT EXISTS idx_project_notes_type ON prsm_frappuccino.project_notes(note_type);
CREATE INDEX IF NOT EXISTS idx_project_notes_pinned ON prsm_frappuccino.project_notes(is_pinned) WHERE is_pinned = true;
CREATE INDEX IF NOT EXISTS idx_project_notes_mentions ON prsm_frappuccino.project_notes USING GIN(mentions);

-- Activities
CREATE INDEX IF NOT EXISTS idx_team_activities_team ON prsm_frappuccino.team_activities(team_id);
CREATE INDEX IF NOT EXISTS idx_team_activities_project ON prsm_frappuccino.team_activities(project_id);
CREATE INDEX IF NOT EXISTS idx_team_activities_created ON prsm_frappuccino.team_activities(created_at DESC);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_team_notifications_user ON prsm_frappuccino.team_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_team_notifications_unread ON prsm_frappuccino.team_notifications(user_id, is_read) WHERE is_read = false;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE prsm_frappuccino.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.project_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.project_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.project_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.note_read_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.project_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.team_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.team_notifications ENABLE ROW LEVEL SECURITY;

-- Service role policies
CREATE POLICY "Service role full access" ON prsm_frappuccino.roles FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.user_roles FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.project_categories FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.project_assignments FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.task_assignments FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.project_notes FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.note_read_receipts FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.project_templates FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.team_activities FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.team_notifications FOR ALL USING (true);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to check user permissions
CREATE OR REPLACE FUNCTION prsm_frappuccino.check_user_permission(
  p_user_id UUID,
  p_permission TEXT,
  p_team_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  has_permission BOOLEAN := false;
  user_role RECORD;
BEGIN
  FOR user_role IN
    SELECT r.permissions
    FROM prsm_frappuccino.user_roles ur
    JOIN prsm_frappuccino.roles r ON r.id = ur.role_id
    WHERE ur.user_id = p_user_id
      AND ur.is_active = true
      AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
      AND (p_team_id IS NULL OR ur.team_id IS NULL OR ur.team_id = p_team_id)
  LOOP
    -- Check for 'all' permission
    IF user_role.permissions->>'all' = 'true' THEN
      RETURN true;
    END IF;

    -- Check specific permission path (e.g., 'teams.create')
    IF user_role.permissions #>> string_to_array(p_permission, '.') = 'true' THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN has_permission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's highest role in a team
CREATE OR REPLACE FUNCTION prsm_frappuccino.get_user_team_role(
  p_user_id UUID,
  p_team_id UUID
)
RETURNS TABLE(role_name TEXT, hierarchy_level INTEGER) AS $$
BEGIN
  RETURN QUERY
  SELECT r.name::TEXT, r.hierarchy_level
  FROM prsm_frappuccino.user_roles ur
  JOIN prsm_frappuccino.roles r ON r.id = ur.role_id
  WHERE ur.user_id = p_user_id
    AND (ur.team_id = p_team_id OR ur.team_id IS NULL)
    AND ur.is_active = true
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
  ORDER BY r.hierarchy_level DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update team workload
CREATE OR REPLACE FUNCTION prsm_frappuccino.update_team_workload()
RETURNS TRIGGER AS $$
BEGIN
  -- Update team's current workload
  UPDATE prsm_frappuccino.teams t
  SET current_workload = (
    SELECT COALESCE(SUM(pa.estimated_hours), 0)
    FROM prsm_frappuccino.project_assignments pa
    WHERE pa.team_id = t.id
      AND pa.status = 'active'
  )
  WHERE t.id = COALESCE(NEW.team_id, OLD.team_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_team_workload_trigger
AFTER INSERT OR UPDATE OR DELETE ON prsm_frappuccino.project_assignments
FOR EACH ROW EXECUTE FUNCTION prsm_frappuccino.update_team_workload();

-- Function to update member workload
CREATE OR REPLACE FUNCTION prsm_frappuccino.update_member_workload()
RETURNS TRIGGER AS $$
BEGIN
  -- Update member's current workload
  UPDATE prsm_frappuccino.team_members tm
  SET current_workload = (
    SELECT COALESCE(SUM(pa.estimated_hours * pa.allocation_percentage / 100), 0)
    FROM prsm_frappuccino.project_assignments pa
    WHERE pa.user_id = tm.user_id
      AND pa.team_id = tm.team_id
      AND pa.status = 'active'
  )
  WHERE tm.user_id = COALESCE(NEW.user_id, OLD.user_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_member_workload_trigger
AFTER INSERT OR UPDATE OR DELETE ON prsm_frappuccino.project_assignments
FOR EACH ROW EXECUTE FUNCTION prsm_frappuccino.update_member_workload();

-- Function to increment reply count on notes
CREATE OR REPLACE FUNCTION prsm_frappuccino.update_note_thread_count()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.parent_id IS NOT NULL THEN
    UPDATE prsm_frappuccino.project_notes
    SET thread_count = thread_count + 1
    WHERE id = NEW.parent_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_note_thread_count_trigger
AFTER INSERT ON prsm_frappuccino.project_notes
FOR EACH ROW EXECUTE FUNCTION prsm_frappuccino.update_note_thread_count();

-- Apply update triggers
CREATE TRIGGER update_project_assignments_updated_at
  BEFORE UPDATE ON prsm_frappuccino.project_assignments
  FOR EACH ROW
  EXECUTE FUNCTION prsm_frappuccino.update_updated_at();

CREATE TRIGGER update_project_notes_updated_at
  BEFORE UPDATE ON prsm_frappuccino.project_notes
  FOR EACH ROW
  EXECUTE FUNCTION prsm_frappuccino.update_updated_at();

CREATE TRIGGER update_project_templates_updated_at
  BEFORE UPDATE ON prsm_frappuccino.project_templates
  FOR EACH ROW
  EXECUTE FUNCTION prsm_frappuccino.update_updated_at();

-- ============================================================================
-- SEED DATA FOR PROJECT CATEGORIES
-- ============================================================================

INSERT INTO prsm_frappuccino.project_categories (name, description, color, icon) VALUES
  ('Development', 'Software development projects', '#3b82f6', 'code'),
  ('Design', 'UI/UX and graphic design projects', '#8b5cf6', 'palette'),
  ('Marketing', 'Marketing campaigns and initiatives', '#ec4899', 'megaphone'),
  ('Infrastructure', 'DevOps and infrastructure projects', '#f59e0b', 'server'),
  ('Research', 'Research and exploration projects', '#10b981', 'search'),
  ('Client Work', 'Client-facing project work', '#06b6d4', 'briefcase'),
  ('Internal', 'Internal tools and improvements', '#6366f1', 'home'),
  ('Maintenance', 'Bug fixes and maintenance work', '#64748b', 'wrench')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Enterprise Team Management migration completed!';
  RAISE NOTICE 'New tables: roles, user_roles, project_categories, project_assignments, task_assignments, project_notes, note_read_receipts, project_templates, team_activities, team_notifications';
  RAISE NOTICE 'Enhanced: teams, team_members, projects';
END $$;
