using System.Diagnostics;
using System.IO;
using System.Text.Json.Nodes;

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

                try
                {
                    process.Start();
                    process.WaitForExit();
                    stdout = process.StandardOutput.ReadToEnd();
                    stderr = process.StandardError.ReadToEnd();
                    exitCode = process.ExitCode;
                }
                catch(Exception ex)
                {
                    exitCode = 1;
                    _controller.LoadError(ex);
                }
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
            try
            {
                RunCommand(args);
            }
            catch(Exception ex)
            {
                _controller.LoadError(ex);
            }
        }

        public static void Deny(string enrollmentId)
        {
            var args = $"deny -a \"{_controller.DeviceAtsign}\" -i {enrollmentId}";
            try
            {
                RunCommand(args);
            }
            catch(Exception ex)
            {
                _controller.LoadError(ex);
            }
        }

        public static string GenerateOTP()
        {
            var args = $"otp -a \"{_controller.DeviceAtsign}\"";
            try
            {
                return RunCommand(args);
            }
            catch(Exception ex)
            {
                _controller.LoadError(ex);
                return "";
            }
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
            if(returnString.Count < 1)
            {
                // Most likely at_activate binary is missing if the output was empty
                _controller.LoadError(new Exception("No output from at_activate status"));
            }
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
            string devName = _controller.DeviceName;
            var args =
                $"enroll -a \"{_controller.DeviceAtsign}\" -s \"{otp}\" -p \"{AppName}\" -d \"{devName}\" -n \"sshnp:rw,sshrvd:rw\" -k \"{Path.Combine(_controller.AtsignKeysDirectory, _controller.DeviceAtsign + "_key.atKeys")}\"";
            string response = "";
            try
            {
                response = RunCommand(args);
            }
            catch(Exception ex)
            {
                _controller.LoadError(ex);
            }

            if (response.Contains("[Success]"))
            {
                return true;
            }

            return false;
        }

        public static List<EnrollmentRecord> ListEnrollments()
        {
            var args = $"list -a \"{_controller.DeviceAtsign}\" -s pending";
            var response = "";
            try
            {
                response = RunCommand(args);
            }
            catch(Exception ex)
            {
                _controller.LoadError(ex);
            }
            List<string> strings = response.Split("\n").ToList();
            List<EnrollmentRecord> lines = [];
            for (int i = 2; i < strings.Count; i++) 
            {
                var parts = strings[i].Trim().Split().ToList();
                if (parts.Count < 4) continue;
                parts.RemoveAll(x => x == "");

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
                string enrollmentId = "";
                var fileContent = File.ReadAllText(dir);
                if (fileContent.Contains("enrollmentId"))
                {
                    try
                    {
                        var json = JsonObject.Parse(fileContent);
                        if (json != null) enrollmentId = (String?)json["enrollmentId"] ?? "";
                    }
                    catch
                    {
                        throw new Exception("Failed to parse the atKeys file json");
                    }
                    var args = $"list -a \"{atsign}\" -s \"approved\"";
                    var response = RunCommand(args);

                    List<string> strings = response.Split("\n").ToList();
                    int count = strings.Count;
                    for (int i = 2; i <= count; i++)
                    {
                        if (strings[i].Contains(enrollmentId))
                        {
                            var braceStart = strings[i].IndexOf("{");
                            var braceEnd = strings[i].IndexOf("}");
                            if (braceStart != -1 && braceEnd != -1)
                            {
                                var permissions = strings[i].Substring(braceStart, braceEnd - braceStart);
                                return permissions.Contains("__manage: rw") && permissions.Contains("*: rw");
                            }
                        }
                    }

                    return false;
				}
				else
				{
					return true;
				}
			} 
            throw new Exception("Failed to locate atKeys file");
        }
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
