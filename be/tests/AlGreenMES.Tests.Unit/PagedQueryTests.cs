using AlGreenMES.BuildingBlocks.Common.Pagination;
using FluentAssertions;
using Xunit;

namespace AlGreenMES.Tests.Unit;

/// <summary>
/// Guards PagedQuery.GetPageSize bounds. Regression: the cap used to be 100,
/// which silently truncated every dashboard Excel export (which sends
/// pageSize 10000 to mean "fetch everything") to the first 100 rows — Mile
/// reported the orders export only returning the first page once the list
/// grew past 100 (2026-10).
/// </summary>
public class PagedQueryTests
{
    private sealed record Query : PagedQuery<object>;

    [Theory]
    [InlineData(20, 20)]        // normal page size passes through
    [InlineData(0, 20)]         // < 1 falls back to the default
    [InlineData(-5, 20)]        // negative falls back to the default
    [InlineData(100, 100)]      // within bounds
    [InlineData(10000, 10000)]  // the export sentinel must NOT be truncated
    [InlineData(99999, 10000)]  // anything above the cap is clamped to the max
    public void GetPageSize_ClampsToBounds(int requested, int expected)
    {
        var query = new Query { PageSize = requested };
        query.GetPageSize().Should().Be(expected);
    }
}
