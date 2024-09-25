namespace NoPortsInstaller
{
    public class AccessEntry : IAccessEntry
    {
        String atSign { get; set; }
        AccessType type { get; set; }

        AccessEntry()
        {
            atSign = "";
            type = AccessType.Manager;
        }
    }

    public class AccessRules : IAccessRules
    {
        List<AccessEntry> entries { get; set; }

        List<AccessEntry> managers
        {
            get { return entries.FindAll(IsManager); }
        }

        AccessRules policy
        {
            get { return entries.Find(IsPolicy); }
        }

        bool IsValid
        {
            get { return entries.Count > 0; }
        }

        AccessRules()
        {
            entries = List<AccessEntry>();
        }

        void SetEntryType(String atSign, AccessType type)
        {
            // Unset the current policy atSign if it exists (there can only be one)
            if (type == AccessType.Policy)
            {
                policy.type = AccessType.Manager;
            }
            entries.Find(IsAtsign).type = type;
        }

        private static bool IsManager(AccessEntry entry)
        {
            return entry.type == AccessType.Manager;
        }

        private static bool IsAtsign(String atSign)
        {
            return entry.atSign == atSign;
        }

        private static bool IsPolicy(AccessEntry entry)
        {
            return entry.type == AccessType.Policy;
        }
    }
}
