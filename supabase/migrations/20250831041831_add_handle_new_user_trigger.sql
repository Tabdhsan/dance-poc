-- Trigger to automatically handle new user creation from Supabase auth
-- This trigger ensures new users are properly created in the public.users table
-- and choreographer profiles are created when needed
CREATE TRIGGER trigger_handle_new_user
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();