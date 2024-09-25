namespace NoPortsInstaller
{
    public enum AccessType
    {
        Manager,
        Policy,
    }

    public class IAccessEntry
    {
        String atSign { get; set; }
        AccessType type { get; set; }
    }

    public class IAccessRules
    {
        List<IAccessEntry> entries { get; set; }
        List<IAccessEntry> managers { get; }
        IAccessEntry policy { get; }

        bool IsValid { get; }

        void SetEntryType(String atSign, AccessType type);
    }
}
