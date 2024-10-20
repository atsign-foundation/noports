using System.IO;

namespace NoPortsInstaller
{
    internal class InstallLogger
    {
        private static readonly string LogDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NoPortsInstaller");
        private static readonly string LogFile = Path.Combine(LogDirectory, "install.log");
        private static readonly List<string> LogMessages = [];

        public static void Log(string message)
        {
            LogMessages.Add($"{DateTime.Now} - {message}");
        }

        public static void DumpLog()
        {
            if (!Directory.Exists(LogDirectory))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogFile)!);
            }
            if (File.Exists(LogFile))
            {
                File.Delete(LogFile);
            }
            using StreamWriter stream = new(File.Create(LogFile));
            foreach (string message in LogMessages)
            {
                stream.WriteLine(message);
            }
        }
    }
}