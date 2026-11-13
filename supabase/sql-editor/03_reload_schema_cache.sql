-- Safe cache notification, no data mutation. Run after checking schema and grants.
NOTIFY pgrst, 'reload schema';
