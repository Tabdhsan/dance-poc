-- Audit schema: lightweight audit logs, insert RPC, and example triggers
-- This file provides a minimal, pragmatic audit trail for critical operations.

CREATE SCHEMA IF NOT EXISTS audit;

-- Primary audit table. Keep payload and meta flexible as JSONB for later analysis.
CREATE TABLE IF NOT EXISTS audit.audit_logs (
  id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  actor_user_id uuid NULL,
  target_table text NOT NULL,
  target_id text NULL,
  action text NOT NULL,
  payload jsonb NULL,
  meta jsonb NULL
);

-- Useful indexes for common queries: by time, by target, by actor
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit.audit_logs (created_at);
CREATE INDEX IF NOT EXISTS idx_audit_target_table_id ON audit.audit_logs (target_table, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit.audit_logs (actor_user_id);

-- Lightweight, reusable RPC to insert an audit row. SECURITY DEFINER so app-level
-- callers (web role) can invoke this through thin trigger functions without
-- requiring broad table-level privileges.
CREATE OR REPLACE FUNCTION audit.log_insert(
  p_actor_user_id uuid,
  p_target_table text,
  p_target_id text,
  p_action text,
  p_payload jsonb DEFAULT '{}'::jsonb,
  p_meta jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO audit.audit_logs (actor_user_id, target_table, target_id, action, payload, meta)
  VALUES (
    p_actor_user_id,
    p_target_table,
    p_target_id,
    upper(p_action),
    COALESCE(p_payload, '{}'::jsonb),
    COALESCE(p_meta, '{}'::jsonb)
  );
END;
$$;

-- Helper: read the current actor from JWT claims if set (Supabase sets jwt.claims.user_id).
-- Returns NULL when the claim isn't present (eg. background jobs).
CREATE OR REPLACE FUNCTION audit.get_current_actor() RETURNS uuid
LANGUAGE sql
AS $$
  SELECT CASE WHEN current_setting('jwt.claims.user_id', true) IS NULL
              THEN NULL
              ELSE current_setting('jwt.claims.user_id', true)::uuid
         END;
$$;

-- Trigger function for classes: log CREATE / UPDATE (meaningful column changes) / DELETE
CREATE OR REPLACE FUNCTION audit.trigger_classes() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor uuid := audit.get_current_actor();
  v_action text;
  v_tgt_id text;
  v_payload jsonb;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    v_action := 'CREATE';
    v_tgt_id := NEW.id::text;
    v_payload := jsonb_build_object('new', to_jsonb(NEW));
    PERFORM audit.log_insert(v_actor, 'classes', v_tgt_id, v_action, v_payload);
    RETURN NEW;

  ELSIF (TG_OP = 'UPDATE') THEN
    -- Only log updates when relevant business columns change to avoid noise
    IF (ROW(OLD.title, OLD.description, OLD.class_timestamp, OLD.location_name, OLD.price, OLD.deleted_at)
        IS DISTINCT FROM ROW(NEW.title, NEW.description, NEW.class_timestamp, NEW.location_name, NEW.price, NEW.deleted_at)) THEN
      v_action := 'UPDATE';
      v_tgt_id := NEW.id::text;
      v_payload := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      PERFORM audit.log_insert(v_actor, 'classes', v_tgt_id, v_action, v_payload);
    END IF;
    RETURN NEW;

  ELSIF (TG_OP = 'DELETE') THEN
    v_action := 'DELETE';
    v_tgt_id := OLD.id::text;
    v_payload := jsonb_build_object('old', to_jsonb(OLD));
    PERFORM audit.log_insert(v_actor, 'classes', v_tgt_id, v_action, v_payload);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

-- Attach trigger to classes (idempotent: drop existing trigger first)
DROP TRIGGER IF EXISTS classes_audit_trigger ON classes;
CREATE TRIGGER classes_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON classes
FOR EACH ROW EXECUTE FUNCTION audit.trigger_classes();

-- Trigger function for users: focus on role changes (and optionally creation/deletion)
CREATE OR REPLACE FUNCTION audit.trigger_users_roles() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor uuid := audit.get_current_actor();
  v_payload jsonb;
BEGIN
  IF (TG_OP = 'UPDATE') THEN
    IF OLD.role IS DISTINCT FROM NEW.role THEN
      v_payload := jsonb_build_object('user_id', NEW.id, 'old_role', OLD.role, 'new_role', NEW.role);
      PERFORM audit.log_insert(v_actor, 'users', NEW.id::text, 'ROLE_CHANGE', v_payload);
    END IF;

  ELSIF (TG_OP = 'INSERT') THEN
    PERFORM audit.log_insert(v_actor, 'users', NEW.id::text, 'CREATE', jsonb_build_object('new', to_jsonb(NEW)));

  ELSIF (TG_OP = 'DELETE') THEN
    PERFORM audit.log_insert(v_actor, 'users', OLD.id::text, 'DELETE', jsonb_build_object('old', to_jsonb(OLD)));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_audit_trigger ON users;
CREATE TRIGGER users_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE FUNCTION audit.trigger_users_roles();

-- Trigger function for choreographer_profiles: log profile field changes
CREATE OR REPLACE FUNCTION audit.trigger_choreographer_profiles() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor uuid := audit.get_current_actor();
  v_payload jsonb;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    PERFORM audit.log_insert(v_actor, 'choreographer_profiles', NEW.id::text, 'CREATE', jsonb_build_object('new', to_jsonb(NEW)));
    RETURN NEW;

  ELSIF (TG_OP = 'UPDATE') THEN
    IF ROW(OLD.bio, OLD.social_links, OLD.profile_picture_url, OLD.display_name, OLD.deleted_at)
        IS DISTINCT FROM ROW(NEW.bio, NEW.social_links, NEW.profile_picture_url, NEW.display_name, NEW.deleted_at) THEN
      v_payload := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      PERFORM audit.log_insert(v_actor, 'choreographer_profiles', NEW.id::text, 'UPDATE', v_payload);
    END IF;
    RETURN NEW;

  ELSIF (TG_OP = 'DELETE') THEN
    PERFORM audit.log_insert(v_actor, 'choreographer_profiles', OLD.id::text, 'DELETE', jsonb_build_object('old', to_jsonb(OLD)));
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS choreographer_profiles_audit_trigger ON choreographer_profiles;
CREATE TRIGGER choreographer_profiles_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON choreographer_profiles
FOR EACH ROW EXECUTE FUNCTION audit.trigger_choreographer_profiles();

-- Notes:
-- - These triggers are intentionally thin: they build a compact JSON payload and call
--   the `audit.log_insert` RPC. If you prefer queueing/async ingestion, replace the
--   PERFORM calls with inserts into a small staging table and process with a worker.
-- - Consider enabling RLS on audit.audit_logs to restrict reads to an "audit" role.
-- - Consider periodic archival/retention (eg. move rows older than 365 days to an archive schema).
