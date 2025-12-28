-- ============================================================================
-- PRSM-Frappuccino CRM Schema for Supabase
-- ============================================================================
-- A comprehensive CRM schema inspired by Frappe CRM patterns
-- Includes: Leads, Deals, Contacts, Organizations, Tasks, Activities,
--           Team Assignments, Contracts, and Project Management
-- ============================================================================

-- Create the schema
CREATE SCHEMA IF NOT EXISTS prsm_frappuccino;

-- ============================================================================
-- CORE CRM TABLES
-- ============================================================================

-- Organizations (Companies/Accounts)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  website VARCHAR(500),
  industry VARCHAR(100),
  company_size VARCHAR(50), -- '1-10', '11-50', '51-200', '201-500', '500+'
  annual_revenue DECIMAL(15, 2),
  currency VARCHAR(3) DEFAULT 'USD',
  address_line1 VARCHAR(255),
  address_line2 VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100),
  postal_code VARCHAR(20),
  phone VARCHAR(50),
  email VARCHAR(255),
  logo_url TEXT,
  tags TEXT[],
  custom_fields JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Contacts (People)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES prsm_frappuccino.organizations(id) ON DELETE SET NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100),
  full_name VARCHAR(255) GENERATED ALWAYS AS (
    CASE
      WHEN last_name IS NOT NULL THEN first_name || ' ' || last_name
      ELSE first_name
    END
  ) STORED,
  email VARCHAR(255),
  email_secondary VARCHAR(255),
  phone VARCHAR(50),
  phone_mobile VARCHAR(50),
  job_title VARCHAR(100),
  department VARCHAR(100),
  linkedin_url VARCHAR(500),
  twitter_handle VARCHAR(100),
  avatar_url TEXT,
  address_line1 VARCHAR(255),
  address_line2 VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100),
  postal_code VARCHAR(20),
  timezone VARCHAR(50),
  preferred_contact_method VARCHAR(50), -- 'email', 'phone', 'whatsapp'
  tags TEXT[],
  custom_fields JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  last_contacted_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lead Sources
CREATE TABLE IF NOT EXISTS prsm_frappuccino.lead_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pipeline Stages (for Leads and Deals)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.pipeline_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_type VARCHAR(50) NOT NULL, -- 'lead', 'deal'
  name VARCHAR(100) NOT NULL,
  description TEXT,
  color VARCHAR(7), -- hex color
  position INTEGER NOT NULL,
  probability DECIMAL(3, 2) DEFAULT 0, -- 0.00 to 1.00
  is_won BOOLEAN DEFAULT false,
  is_lost BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(pipeline_type, name)
);

-- Leads
CREATE TABLE IF NOT EXISTS prsm_frappuccino.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID REFERENCES prsm_frappuccino.contacts(id) ON DELETE SET NULL,
  organization_id UUID REFERENCES prsm_frappuccino.organizations(id) ON DELETE SET NULL,
  stage_id UUID REFERENCES prsm_frappuccino.pipeline_stages(id),
  source_id UUID REFERENCES prsm_frappuccino.lead_sources(id),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  value DECIMAL(15, 2),
  currency VARCHAR(3) DEFAULT 'USD',
  priority VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high', 'urgent'
  score INTEGER DEFAULT 0, -- lead scoring 0-100
  assigned_to UUID,
  assigned_at TIMESTAMPTZ,
  converted_to_deal_id UUID,
  converted_at TIMESTAMPTZ,
  lost_reason TEXT,
  expected_close_date DATE,
  first_response_at TIMESTAMPTZ,
  last_activity_at TIMESTAMPTZ,
  tags TEXT[],
  custom_fields JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deals (Opportunities)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.deals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES prsm_frappuccino.leads(id) ON DELETE SET NULL,
  contact_id UUID REFERENCES prsm_frappuccino.contacts(id) ON DELETE SET NULL,
  organization_id UUID REFERENCES prsm_frappuccino.organizations(id) ON DELETE SET NULL,
  stage_id UUID REFERENCES prsm_frappuccino.pipeline_stages(id),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  value DECIMAL(15, 2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'USD',
  probability DECIMAL(3, 2) DEFAULT 0.50,
  weighted_value DECIMAL(15, 2) GENERATED ALWAYS AS (value * probability) STORED,
  priority VARCHAR(20) DEFAULT 'medium',
  deal_type VARCHAR(50), -- 'new_business', 'upsell', 'renewal', 'expansion'
  assigned_to UUID,
  assigned_at TIMESTAMPTZ,
  expected_close_date DATE,
  actual_close_date DATE,
  won_at TIMESTAMPTZ,
  lost_at TIMESTAMPTZ,
  lost_reason TEXT,
  competitor VARCHAR(255),
  last_activity_at TIMESTAMPTZ,
  tags TEXT[],
  custom_fields JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- WORKFLOW & ACTIVITY TABLES
-- ============================================================================

-- Activity Types
CREATE TABLE IF NOT EXISTS prsm_frappuccino.activity_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  icon VARCHAR(50),
  color VARCHAR(7),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activities (Calls, Meetings, Emails, etc.)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_type_id UUID REFERENCES prsm_frappuccino.activity_types(id),
  entity_type VARCHAR(50) NOT NULL, -- 'lead', 'deal', 'contact', 'organization'
  entity_id UUID NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  scheduled_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  duration_minutes INTEGER,
  location VARCHAR(255),
  meeting_link VARCHAR(500),
  outcome VARCHAR(100), -- 'completed', 'cancelled', 'rescheduled', 'no_show'
  outcome_notes TEXT,
  reminder_at TIMESTAMPTZ,
  is_all_day BOOLEAN DEFAULT false,
  assigned_to UUID,
  participants UUID[],
  attachments JSONB DEFAULT '[]',
  custom_fields JSONB DEFAULT '{}',
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tasks
CREATE TABLE IF NOT EXISTS prsm_frappuccino.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(50), -- 'lead', 'deal', 'contact', 'organization', 'project'
  entity_id UUID,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  priority VARCHAR(20) DEFAULT 'medium',
  status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'cancelled'
  due_date DATE,
  due_time TIME,
  completed_at TIMESTAMPTZ,
  assigned_to UUID,
  assigned_by UUID,
  assigned_at TIMESTAMPTZ,
  reminder_at TIMESTAMPTZ,
  tags TEXT[],
  checklist JSONB DEFAULT '[]', -- [{id, text, checked}]
  custom_fields JSONB DEFAULT '{}',
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notes
CREATE TABLE IF NOT EXISTS prsm_frappuccino.notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(50) NOT NULL,
  entity_id UUID NOT NULL,
  content TEXT NOT NULL,
  is_pinned BOOLEAN DEFAULT false,
  mentions UUID[],
  attachments JSONB DEFAULT '[]',
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TEAM & ASSIGNMENT TABLES
-- ============================================================================

-- Teams
CREATE TABLE IF NOT EXISTS prsm_frappuccino.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  manager_id UUID,
  color VARCHAR(7),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Team Members
CREATE TABLE IF NOT EXISTS prsm_frappuccino.team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES prsm_frappuccino.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  role VARCHAR(50) DEFAULT 'member', -- 'manager', 'member'
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  left_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  UNIQUE(team_id, user_id)
);

-- Assignment Rules (auto-assignment)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.assignment_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  entity_type VARCHAR(50) NOT NULL, -- 'lead', 'deal'
  conditions JSONB NOT NULL, -- filtering conditions
  assignment_type VARCHAR(50) NOT NULL, -- 'round_robin', 'load_balance', 'specific_user', 'specific_team'
  assigned_users UUID[],
  assigned_team_id UUID REFERENCES prsm_frappuccino.teams(id),
  priority INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- CONTRACT & PROJECT TABLES
-- ============================================================================

-- Contract Templates
CREATE TABLE IF NOT EXISTS prsm_frappuccino.contract_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  content TEXT NOT NULL,
  placeholders JSONB DEFAULT '[]', -- [{key, label, type, required}]
  category VARCHAR(100),
  version INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Contracts
CREATE TABLE IF NOT EXISTS prsm_frappuccino.contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id UUID REFERENCES prsm_frappuccino.deals(id) ON DELETE SET NULL,
  organization_id UUID REFERENCES prsm_frappuccino.organizations(id) ON DELETE SET NULL,
  contact_id UUID REFERENCES prsm_frappuccino.contacts(id) ON DELETE SET NULL,
  template_id UUID REFERENCES prsm_frappuccino.contract_templates(id),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  content TEXT,
  status VARCHAR(50) DEFAULT 'draft', -- 'draft', 'pending_review', 'sent', 'viewed', 'signed', 'expired', 'cancelled'
  value DECIMAL(15, 2),
  currency VARCHAR(3) DEFAULT 'USD',
  start_date DATE,
  end_date DATE,
  renewal_date DATE,
  auto_renew BOOLEAN DEFAULT false,
  renewal_terms TEXT,
  sent_at TIMESTAMPTZ,
  viewed_at TIMESTAMPTZ,
  signed_at TIMESTAMPTZ,
  signed_by VARCHAR(255),
  signature_ip VARCHAR(45),
  document_url TEXT,
  signed_document_url TEXT,
  tags TEXT[],
  custom_fields JSONB DEFAULT '{}',
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Projects
CREATE TABLE IF NOT EXISTS prsm_frappuccino.projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id UUID REFERENCES prsm_frappuccino.deals(id) ON DELETE SET NULL,
  contract_id UUID REFERENCES prsm_frappuccino.contracts(id) ON DELETE SET NULL,
  organization_id UUID REFERENCES prsm_frappuccino.organizations(id) ON DELETE SET NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  status VARCHAR(50) DEFAULT 'planning', -- 'planning', 'in_progress', 'on_hold', 'completed', 'cancelled'
  priority VARCHAR(20) DEFAULT 'medium',
  start_date DATE,
  end_date DATE,
  actual_start_date DATE,
  actual_end_date DATE,
  budget DECIMAL(15, 2),
  spent DECIMAL(15, 2) DEFAULT 0,
  currency VARCHAR(3) DEFAULT 'USD',
  progress INTEGER DEFAULT 0, -- 0-100
  manager_id UUID,
  team_id UUID REFERENCES prsm_frappuccino.teams(id),
  tags TEXT[],
  custom_fields JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Project Milestones
CREATE TABLE IF NOT EXISTS prsm_frappuccino.project_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES prsm_frappuccino.projects(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  due_date DATE,
  completed_at TIMESTAMPTZ,
  position INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- COMMUNICATION & INTEGRATION TABLES
-- ============================================================================

-- Email Templates
CREATE TABLE IF NOT EXISTS prsm_frappuccino.email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  subject VARCHAR(500) NOT NULL,
  body TEXT NOT NULL,
  category VARCHAR(100),
  placeholders JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email Campaigns
CREATE TABLE IF NOT EXISTS prsm_frappuccino.email_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  template_id UUID REFERENCES prsm_frappuccino.email_templates(id),
  subject VARCHAR(500),
  body TEXT,
  status VARCHAR(50) DEFAULT 'draft', -- 'draft', 'scheduled', 'sending', 'sent', 'cancelled'
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  segment_filters JSONB DEFAULT '{}',
  recipient_count INTEGER DEFAULT 0,
  sent_count INTEGER DEFAULT 0,
  opened_count INTEGER DEFAULT 0,
  clicked_count INTEGER DEFAULT 0,
  bounced_count INTEGER DEFAULT 0,
  unsubscribed_count INTEGER DEFAULT 0,
  tags TEXT[],
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Call Logs (Twilio/Exotel integration ready)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.call_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(50),
  entity_id UUID,
  contact_id UUID REFERENCES prsm_frappuccino.contacts(id),
  direction VARCHAR(20) NOT NULL, -- 'inbound', 'outbound'
  status VARCHAR(50), -- 'completed', 'busy', 'no_answer', 'failed', 'voicemail'
  from_number VARCHAR(50),
  to_number VARCHAR(50),
  duration_seconds INTEGER,
  recording_url TEXT,
  transcription TEXT,
  sentiment VARCHAR(20), -- 'positive', 'neutral', 'negative'
  notes TEXT,
  provider VARCHAR(50), -- 'twilio', 'exotel'
  provider_call_id VARCHAR(255),
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  user_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ANALYTICS & REPORTING TABLES
-- ============================================================================

-- Analytics Events
CREATE TABLE IF NOT EXISTS prsm_frappuccino.analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50),
  entity_id UUID,
  user_id UUID,
  event_data JSONB DEFAULT '{}',
  session_id VARCHAR(255),
  user_agent TEXT,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily Metrics (for dashboards)
CREATE TABLE IF NOT EXISTS prsm_frappuccino.daily_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_date DATE NOT NULL,
  user_id UUID,
  team_id UUID,
  leads_created INTEGER DEFAULT 0,
  leads_converted INTEGER DEFAULT 0,
  deals_created INTEGER DEFAULT 0,
  deals_won INTEGER DEFAULT 0,
  deals_lost INTEGER DEFAULT 0,
  revenue_won DECIMAL(15, 2) DEFAULT 0,
  activities_completed INTEGER DEFAULT 0,
  calls_made INTEGER DEFAULT 0,
  emails_sent INTEGER DEFAULT 0,
  tasks_completed INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(metric_date, user_id, team_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Organizations
CREATE INDEX IF NOT EXISTS idx_prsm_organizations_name ON prsm_frappuccino.organizations(name);
CREATE INDEX IF NOT EXISTS idx_prsm_organizations_industry ON prsm_frappuccino.organizations(industry);

-- Contacts
CREATE INDEX IF NOT EXISTS idx_prsm_contacts_email ON prsm_frappuccino.contacts(email);
CREATE INDEX IF NOT EXISTS idx_prsm_contacts_org ON prsm_frappuccino.contacts(organization_id);
CREATE INDEX IF NOT EXISTS idx_prsm_contacts_name ON prsm_frappuccino.contacts(full_name);

-- Leads
CREATE INDEX IF NOT EXISTS idx_prsm_leads_stage ON prsm_frappuccino.leads(stage_id);
CREATE INDEX IF NOT EXISTS idx_prsm_leads_assigned ON prsm_frappuccino.leads(assigned_to);
CREATE INDEX IF NOT EXISTS idx_prsm_leads_created ON prsm_frappuccino.leads(created_at);
CREATE INDEX IF NOT EXISTS idx_prsm_leads_score ON prsm_frappuccino.leads(score DESC);

-- Deals
CREATE INDEX IF NOT EXISTS idx_prsm_deals_stage ON prsm_frappuccino.deals(stage_id);
CREATE INDEX IF NOT EXISTS idx_prsm_deals_assigned ON prsm_frappuccino.deals(assigned_to);
CREATE INDEX IF NOT EXISTS idx_prsm_deals_close_date ON prsm_frappuccino.deals(expected_close_date);
CREATE INDEX IF NOT EXISTS idx_prsm_deals_value ON prsm_frappuccino.deals(value DESC);

-- Activities
CREATE INDEX IF NOT EXISTS idx_prsm_activities_entity ON prsm_frappuccino.activities(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_prsm_activities_scheduled ON prsm_frappuccino.activities(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_prsm_activities_assigned ON prsm_frappuccino.activities(assigned_to);

-- Tasks
CREATE INDEX IF NOT EXISTS idx_prsm_tasks_entity ON prsm_frappuccino.tasks(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_prsm_tasks_assigned ON prsm_frappuccino.tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_prsm_tasks_due ON prsm_frappuccino.tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_prsm_tasks_status ON prsm_frappuccino.tasks(status);

-- Notes
CREATE INDEX IF NOT EXISTS idx_prsm_notes_entity ON prsm_frappuccino.notes(entity_type, entity_id);

-- Projects
CREATE INDEX IF NOT EXISTS idx_prsm_projects_status ON prsm_frappuccino.projects(status);
CREATE INDEX IF NOT EXISTS idx_prsm_projects_org ON prsm_frappuccino.projects(organization_id);

-- Contracts
CREATE INDEX IF NOT EXISTS idx_prsm_contracts_status ON prsm_frappuccino.contracts(status);
CREATE INDEX IF NOT EXISTS idx_prsm_contracts_deal ON prsm_frappuccino.contracts(deal_id);

-- Analytics
CREATE INDEX IF NOT EXISTS idx_prsm_analytics_type ON prsm_frappuccino.analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_prsm_analytics_entity ON prsm_frappuccino.analytics_events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_prsm_analytics_created ON prsm_frappuccino.analytics_events(created_at);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE prsm_frappuccino.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.lead_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.pipeline_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.activity_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.assignment_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.contract_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.project_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.call_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE prsm_frappuccino.daily_metrics ENABLE ROW LEVEL SECURITY;

-- Service role policies (full access)
CREATE POLICY "Service role full access" ON prsm_frappuccino.organizations FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.contacts FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.lead_sources FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.pipeline_stages FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.leads FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.deals FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.activity_types FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.activities FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.tasks FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.notes FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.teams FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.team_members FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.assignment_rules FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.contract_templates FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.contracts FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.projects FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.project_milestones FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.email_templates FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.email_campaigns FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.call_logs FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.analytics_events FOR ALL USING (true);
CREATE POLICY "Service role full access" ON prsm_frappuccino.daily_metrics FOR ALL USING (true);

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Lead Sources
INSERT INTO prsm_frappuccino.lead_sources (name, description) VALUES
  ('Website', 'Leads from website contact forms'),
  ('Referral', 'Referred by existing customers'),
  ('LinkedIn', 'LinkedIn outreach and campaigns'),
  ('Cold Call', 'Cold calling campaigns'),
  ('Email Campaign', 'Email marketing campaigns'),
  ('Trade Show', 'Trade shows and conferences'),
  ('Partner', 'Partner referrals'),
  ('Organic Search', 'Found through search engines'),
  ('Paid Ads', 'Google/Meta paid advertising'),
  ('Other', 'Other sources')
ON CONFLICT (name) DO NOTHING;

-- Lead Pipeline Stages
INSERT INTO prsm_frappuccino.pipeline_stages (pipeline_type, name, position, probability, color) VALUES
  ('lead', 'New', 1, 0.10, '#3498db'),
  ('lead', 'Contacted', 2, 0.20, '#9b59b6'),
  ('lead', 'Qualified', 3, 0.40, '#1abc9c'),
  ('lead', 'Proposal Sent', 4, 0.60, '#f39c12'),
  ('lead', 'Negotiation', 5, 0.80, '#e67e22'),
  ('lead', 'Converted', 6, 1.00, '#27ae60'),
  ('lead', 'Lost', 7, 0.00, '#e74c3c')
ON CONFLICT (pipeline_type, name) DO NOTHING;

-- Update is_won and is_lost flags
UPDATE prsm_frappuccino.pipeline_stages SET is_won = true WHERE name = 'Converted' AND pipeline_type = 'lead';
UPDATE prsm_frappuccino.pipeline_stages SET is_lost = true WHERE name = 'Lost' AND pipeline_type = 'lead';

-- Deal Pipeline Stages
INSERT INTO prsm_frappuccino.pipeline_stages (pipeline_type, name, position, probability, color) VALUES
  ('deal', 'Qualification', 1, 0.10, '#3498db'),
  ('deal', 'Discovery', 2, 0.20, '#9b59b6'),
  ('deal', 'Proposal', 3, 0.40, '#1abc9c'),
  ('deal', 'Negotiation', 4, 0.60, '#f39c12'),
  ('deal', 'Contract Review', 5, 0.80, '#e67e22'),
  ('deal', 'Closed Won', 6, 1.00, '#27ae60'),
  ('deal', 'Closed Lost', 7, 0.00, '#e74c3c')
ON CONFLICT (pipeline_type, name) DO NOTHING;

-- Update is_won and is_lost flags for deals
UPDATE prsm_frappuccino.pipeline_stages SET is_won = true WHERE name = 'Closed Won' AND pipeline_type = 'deal';
UPDATE prsm_frappuccino.pipeline_stages SET is_lost = true WHERE name = 'Closed Lost' AND pipeline_type = 'deal';

-- Activity Types
INSERT INTO prsm_frappuccino.activity_types (name, icon, color) VALUES
  ('Call', 'phone', '#3498db'),
  ('Meeting', 'users', '#9b59b6'),
  ('Email', 'mail', '#1abc9c'),
  ('Demo', 'monitor', '#f39c12'),
  ('Follow-up', 'clock', '#e67e22'),
  ('Task', 'check-square', '#27ae60'),
  ('Note', 'file-text', '#95a5a6')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION prsm_frappuccino.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers to all tables with updated_at
DO $$
DECLARE
  t text;
BEGIN
  FOR t IN
    SELECT table_name FROM information_schema.columns
    WHERE table_schema = 'prsm_frappuccino'
    AND column_name = 'updated_at'
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS update_%I_updated_at ON prsm_frappuccino.%I;
      CREATE TRIGGER update_%I_updated_at
        BEFORE UPDATE ON prsm_frappuccino.%I
        FOR EACH ROW
        EXECUTE FUNCTION prsm_frappuccino.update_updated_at();
    ', t, t, t, t);
  END LOOP;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify schema creation
DO $$
BEGIN
  RAISE NOTICE 'PRSM-Frappuccino CRM Schema created successfully!';
  RAISE NOTICE 'Tables created: %', (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'prsm_frappuccino'
  );
END $$;
