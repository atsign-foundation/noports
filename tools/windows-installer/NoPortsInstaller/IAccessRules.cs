namespace NoPortsInstaller
{
    public enum AccessType
    {
        Manager,
        Policy,
    }

    public interface IAccessEntry
    {
        string atSign { get; set; }
        AccessType type { get; set; }
    }

    public interface IAccessRules
    {
        List<IAccessEntry> Entries { get; set; }
        List<IAccessEntry> Managers { get; }
        IAccessEntry? Policy { get; }

        bool IsValid { get; }

        void SetEntryType(string atSign, AccessType type);
    }
}
