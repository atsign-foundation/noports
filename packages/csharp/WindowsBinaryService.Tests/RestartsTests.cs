using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

namespace WindowsBinaryService.Tests;

/// <summary>Tests for how long the service waits before it starts its child again.</summary>
public class RestartsTests
{
    [Fact(DisplayName = "Given the child exits at once, when it keeps failing, then each restart waits twice as long up to 60 s")]
    public async Task QuickFailuresDoubleTheWaitUpTo60Seconds()
    {
        List<TimeSpan> waits = await WaitsBetween(Enumerable.Repeat(TimeSpan.Zero, 9));

        Assert.Equal(new double[] { 1, 2, 4, 8, 16, 32, 60, 60, 60 }, waits.Select(w => w.TotalSeconds));
    }

    [Fact(DisplayName = "Given the child ran for over a minute, when it exits, then the next restart waits 1 s")]
    public async Task ALongRunStartsTheWaitsAgainFrom1Second()
    {
        TimeSpan quick = TimeSpan.FromSeconds(1);
        List<TimeSpan> waits = await WaitsBetween(new[] { quick, quick, quick, quick, TimeSpan.FromSeconds(61), quick });

        Assert.Equal(new double[] { 1, 2, 4, 8, 1, 2 }, waits.Select(w => w.TotalSeconds));
    }

    [Fact(DisplayName = "Given the child ran for exactly a minute, when it exits, then the next restart waits 1 s")]
    public async Task ARunOfAMinuteCountsAsLong()
    {
        List<TimeSpan> waits = await WaitsBetween(new[] { TimeSpan.Zero, TimeSpan.Zero, TimeSpan.FromSeconds(60) });

        Assert.Equal(new double[] { 1, 2, 1 }, waits.Select(w => w.TotalSeconds));
    }

    [Fact(DisplayName = "Given the service is waiting to restart, when it is stopped, then it stops without waiting")]
    public async Task AStopEndsTheWaitAtOnce()
    {
        using var stopping = new CancellationTokenSource();
        var waiting = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        int runs = 0;

        Task service = Restarts.RunAsync(
            _ =>
            {
                runs++;
                return Task.CompletedTask;
            },
            (_, ct) =>
            {
                waiting.TrySetResult();
                return Task.Delay(Timeout.InfiniteTimeSpan, ct);
            },
            () => TimeSpan.Zero,
            stopping.Token);
        await waiting.Task.WaitAsync(TimeSpan.FromSeconds(10));
        stopping.Cancel();

        await service.WaitAsync(TimeSpan.FromSeconds(10));
        Assert.Equal(1, runs);
    }

    /// <summary>Runs the restart loop over children that run for each of <paramref name="runs"/> in turn, returning each wait it asked for.</summary>
    private static async Task<List<TimeSpan>> WaitsBetween(IEnumerable<TimeSpan> runs)
    {
        using var stopping = new CancellationTokenSource();
        TimeSpan clock = TimeSpan.Zero;
        var waits = new List<TimeSpan>();
        using IEnumerator<TimeSpan> next = runs.GetEnumerator();
        Assert.True(next.MoveNext(), "no runs");

        await Restarts.RunAsync(
            _ =>
            {
                clock += next.Current;
                return Task.CompletedTask;
            },
            (wait, _) =>
            {
                waits.Add(wait);
                if (!next.MoveNext())
                {
                    stopping.Cancel();
                }

                return Task.CompletedTask;
            },
            () => clock,
            stopping.Token);
        return waits;
    }
}
