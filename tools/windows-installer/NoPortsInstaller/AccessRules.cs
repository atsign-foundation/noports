namespace NoPortsInstaller
{
    public class AccessEntry : IAccessEntry
    {
        public string atSign { get; set; }
        public AccessType type { get; set; }

        AccessEntry()
        {
            atSign = "";
            type = AccessType.Manager;
        }
    }

    public class AccessRules : IAccessRules
    {
        public List<IAccessEntry> Entries { get; set; }

        public List<IAccessEntry> Managers
        {
            get { return Entries.FindAll(entry => IsManager((AccessEntry)entry)); }
        }

        public IAccessEntry? Policy
        {
            get { return Entries.Find(entry => IsPolicy((AccessEntry)entry)); }
        }

        public bool IsValid
        {
            get { return Entries.Count > 0; }
        }

        AccessRules()
        {
            Entries = new();
        }

        public void SetEntryType(string atSign, AccessType type)
        {
            // Unset the current policy atSign if it exists (there can only be one)
            if (type == AccessType.Policy && Policy != null)
            {
                InstallLogger.Log($"Unsetting current policy atSign: {Policy.atSign}");
                Policy.type = AccessType.Manager;
            }
            InstallLogger.Log($"Setting policy atSign: {atSign}");
            Entries.Find(entry => entry.atSign == atSign)!.type = type;
        }

        private static bool IsManager(AccessEntry entry)
        {
            return entry.type == AccessType.Manager;
        }

        private static bool IsPolicy(AccessEntry entry)
        {
            return entry.type == AccessType.Policy;
        }
    }
}
