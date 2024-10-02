using System.Diagnostics;
using System.IO;

namespace NoPortsInstaller
{
    class ActivateController
    {
        private static readonly Controller _controller = App.ControllerInstance;

        /// <summary>
        /// Run a command with the at_activate.exe, if you want the return codes that comes in stdErr, use returnStdErr = true
        /// </summary>
        /// <param name="args"></param>
        /// <param name="returnStdErr">
        /// returns the values that come in stdErr if the errorCode is not 0 (an error exit)
        /// </param>
        /// <returns>stdOut of the command</returns>
        /// <exception cref="System.Exception"></exception>
        private static string RunCommand(string args, bool returnStdErr = false)
        {
            string stdout = "";
            string stderr = "";
            int exitCode;
            using (var process = new Process())
            {
                var startInfo = process.StartInfo;

                startInfo.FileName = Path.Combine(_controller.InstallDirectory, "at_activate.exe");
                startInfo.UseShellExecute = false;
                startInfo.RedirectStandardOutput = true;
                startInfo.RedirectStandardInput = true;
                startInfo.RedirectStandardError = true;
                startInfo.CreateNoWindow = true;
                startInfo.Arguments = args;

                process.Start();

                process.WaitForExit();
                stdout = process.StandardOutput.ReadToEnd();
                stderr = process.StandardError.ReadToEnd();
                exitCode = process.ExitCode;
            }

            if (exitCode != 0 && !returnStdErr)
            {
                throw new System.Exception(string.Join("\n", stderr));
            }
            if (!string.IsNullOrEmpty(stderr) && returnStdErr)
            {
                return stderr;
            }
            return stdout;

        }

        public static void Approve(string enrollmentId)
        {
            var args = $"approve -a \"{_controller.DeviceAtsign}\" -i {enrollmentId}";
            RunCommand(args);
        }

        public static void Deny(string enrollmentId)
        {
            var args = $"deny -a \"{_controller.DeviceAtsign}\" -i {enrollmentId}";
            RunCommand(args);
        }

        public static string GenerateOTP()
        {
            var args = $"otp -a \"{_controller.DeviceAtsign}\"";
            var response = RunCommand(args);

            return response;
        }

        public static AtsignStatus Status(string atsign)
        {
            var args = $"status -a \"{atsign}\"";
            string response = "";
            try
            {
                response = RunCommand(args, true);
            }
            catch (Exception ex)
            {
                _controller.LoadError(ex);
            }
            var returnString = response.Split(":").ToList();
            var exitCode = returnString[0].Split(" ")[1];

            if (exitCode == "0")
            {
                return AtsignStatus.Activated;
            }
            if (exitCode == "1")
            {
                return AtsignStatus.NotActivated;
            }
            return AtsignStatus.DNE;

        }

        private static readonly string AppName = "noports_win";
        private static readonly List<string> Namespaces = ["sshnp: rw, sshrvd: rw", "sshrvd: rw, sshnp: rw"];

        public static bool Enroll(string otp)
        {
            var args =
                $"enroll -a \"{_controller.DeviceAtsign}\" -s {otp} -p {AppName} -d {_controller.DeviceName} -n \"{Namespaces[0]}\" -k {_controller.AtsignKeysDirectory}";
            string response = RunCommand(args);

            if (response.Contains("[Success]"))
            {
                return true;
            }

            return false;
        }

        public static List<EnrollmentRecord> ListEnrollments()
        {
            var args = $"list -a \"{_controller.DeviceAtsign}\" -s pending";
            var response = RunCommand(args);
            List<string> strings = response.Split("\n").ToList();
            int count = strings.Count - 2;
            List<EnrollmentRecord> lines = [];
            if (count == 1)
            {
                throw new Exception("No enrollments found.");
            }
            for (int i = 2; i <= count; i++)
            {
                var parts = strings[i].Trim().Split(" ").ToList();
                parts.RemoveAll(x => x == "");
                if (parts[2] != AppName)
                {
                    continue;
                }

                EnrollmentRecord record = new(parts[0], parts[3]);
                lines.Add(record);
            }
            return lines;
        }

        public static bool CheckIfMPKAM(string atsign)
        {
            var dir = Path.Combine(_controller.AtsignKeysDirectory, atsign + "_key.atKeys");
            if (File.Exists(dir))
            {
                var fileContent = File.ReadAllText(dir);
                if (fileContent.Contains("enrollmentId"))
                {
                    return false;
                }
            }
            return true;
        }

        public class EnrollmentRecord(string Id, string DeviceName)
        {
            public string Id { get; set; } = Id;
            public string DeviceName { get; set; } = DeviceName;
        }

        public enum AtsignStatus
        {
            DNE,
            NotActivated,
            Activated
        }
    }
}
