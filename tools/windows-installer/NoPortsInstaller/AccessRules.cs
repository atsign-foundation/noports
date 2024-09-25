namespace NoPortsInstaller
{
    public class AccessEntry : IAccessEntry
    {
        public String atSign { get; set; }
        public AccessType type { get; set; }

        AccessEntry()
        {
            atSign = "";
            type = AccessType.Manager;
        }
    }

    public class AccessRules : IAccessRules
    {
        public List<AccessEntry> Entries { get; set; }

        public List<AccessEntry> Managers
        {
            get { return Entries.FindAll(IsManager); }
        }

        public AccessRules Policy
        {
            get { return Entries.Find(IsPolicy); }
        }

        public bool IsValid
        {
            get { return Entries.Count > 0; }
        }

        AccessRules()
        {
            Entries = List<AccessEntry>();
        }

        public void SetEntryType(String atSign, AccessType type)
        {
            // Unset the current policy atSign if it exists (there can only be one)
            if (type == AccessType.Policy && Policy != null)
            {
                InstallLogger.Log($"Unsetting current policy atSign: {Policy.atSign}");
                Policy.type = AccessType.Manager;
            }
            InstallLogger.Log($"Setting policy atSign: {atSign}");
            Entries.Find(IsAtsign).type = type;
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
