using System;
using System.Threading;
using System.Threading.Tasks;

namespace WindowsBinaryService
{
	/// <summary>Starts the service's child again each time it ends, waiting longer after each quick failure.</summary>
	internal static class Restarts
	{
		internal static readonly TimeSpan FirstWait = TimeSpan.FromSeconds(1);
		internal static readonly TimeSpan LongestWait = TimeSpan.FromSeconds(60);
		internal static readonly TimeSpan HealthyRun = TimeSpan.FromSeconds(60);

		/// <summary>
		/// Returns the wait before the next start: <see cref="FirstWait"/> after the first run or a run of at least
		/// <see cref="HealthyRun"/>, and otherwise twice <paramref name="lastWait"/>, up to <see cref="LongestWait"/>.
		/// </summary>
		internal static TimeSpan NextWait(TimeSpan? lastWait, TimeSpan ranFor)
		{
			if (lastWait == null || ranFor >= HealthyRun)
			{
				return FirstWait;
			}

			TimeSpan doubled = lastWait.Value * 2;
			return doubled < LongestWait ? doubled : LongestWait;
		}

		/// <summary>
		/// Runs <paramref name="runChild"/> again each time it returns until <paramref name="stopping"/> is cancelled,
		/// waiting with <paramref name="wait"/> for <see cref="NextWait"/> between runs; a stop ends a wait at once.
		/// </summary>
		internal static async Task RunAsync(
			Func<CancellationToken, Task> runChild,
			Func<TimeSpan, CancellationToken, Task> wait,
			Func<TimeSpan> now,
			CancellationToken stopping)
		{
			TimeSpan? lastWait = null;
			while (!stopping.IsCancellationRequested)
			{
				TimeSpan started = now();
				await runChild(stopping);
				lastWait = NextWait(lastWait, now() - started);
				try
				{
					await wait(lastWait.Value, stopping);
				}
				catch (OperationCanceledException) when (stopping.IsCancellationRequested)
				{
					return;
				}
			}
		}
	}
}
