namespace AlGreenMES.BuildingBlocks.Common.Pagination;

/// <summary>
/// Single source of truth for pagination bounds. MaxPageSize is deliberately
/// large so the dashboard's "pageSize: 10000 = fetch everything (for Excel
/// export)" convention works end to end.
///
/// IMPORTANT: both <see cref="PagedQuery{T}.GetPageSize"/> AND
/// <see cref="QueryableExtensions.ToPagedResultAsync"/> must clamp against
/// these same values. They used to each hardcode a cap of 100, which silently
/// truncated every export to the first 100 rows (Mile, 2026-10: orders export
/// only returned the first page once the list grew past 100).
/// </summary>
public static class PaginationDefaults
{
    public const int DefaultPageSize = 20;
    public const int MaxPageSize = 10000;
}
