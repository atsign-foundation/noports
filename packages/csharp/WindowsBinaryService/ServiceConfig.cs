namespace WindowsBinaryService
{
	/// <summary>Names the service, and the atsc subcommand it runs.</summary>
	public static class ServiceConfig
	{
		public const string Binary = "atsc.exe";
#if SRVD
		public const string Subcommand = "srvd";
		public const string Name = "srvd";
		public const string DisplayName = "NoPorts Relay";
#elif SSHNPD
		public const string Subcommand = "sshnpd";
		public const string Name = "sshnpd";
		public const string DisplayName = "NoPorts Daemon";
#else
		public const string Subcommand = "sshnpd";
		public const string Name = "sshnpd";
		public const string DisplayName = "NoPorts Daemon";
#endif
	}
}
