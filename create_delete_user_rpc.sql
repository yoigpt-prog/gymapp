-- Create a function to allow users to delete their own account
CREATE OR REPLACE FUNCTION delete_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- extremely important: allows function to bypass RLS and delete from auth.users
SET search_path = public
AS $$
BEGIN
  -- We use auth.uid() to ensure the user can only delete themselves.
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete the user from auth.users
  -- (Assuming foreign keys in public schema have ON DELETE CASCADE. If not, we might need to delete them explicitly here)
  DELETE FROM auth.users WHERE id = auth.uid();

END;
$$;
