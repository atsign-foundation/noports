using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace WindowsBinaryService
{
	/// <summary>Says how the service starts the program it runs.</summary>
	internal static class ChildProcess
	{
		/// <summary>
		/// Returns the start info that runs <see cref="ServiceConfig.Binary"/> in <paramref name="directory"/>
		/// as <see cref="ServiceConfig.Subcommand"/>, passing each of <paramref name="arguments"/> on unchanged.
		/// </summary>
		internal static ProcessStartInfo StartInfo(string directory, IEnumerable<string> arguments)
		{
			var startInfo = new ProcessStartInfo
			{
				CreateNoWindow = true,
				UseShellExecute = false,
				FileName = Path.Join(directory, ServiceConfig.Binary),
				WindowStyle = ProcessWindowStyle.Hidden,
				RedirectStandardError = true,
				RedirectStandardOutput = true,
			};
			startInfo.ArgumentList.Add(ServiceConfig.Subcommand);
			foreach (string argument in arguments)
			{
				startInfo.ArgumentList.Add(argument);
			}

			return startInfo;
		}
	}
}
