using MediatR;

namespace AlGreenMES.BuildingBlocks.Common.Pagination;

public abstract record PagedQuery<TResponse> : IRequest<TResponse>
{
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 20;
    public string? Search { get; init; }
    public string? SortBy { get; init; }
    public string? SortDirection { get; init; }
    public DateTime? CreatedFrom { get; init; }
    public DateTime? CreatedTo { get; init; }

    public bool IsDescending => string.Equals(SortDirection, "desc", StringComparison.OrdinalIgnoreCase);

    public int GetPage() => Page < 1 ? 1 : Page;

    // Upper bound guards against runaway queries while honouring the app-wide
    // "pageSize: 10000 = fetch everything (for Excel export)" convention the
    // dashboard relies on in ~13 places. The previous cap of 100 silently
    // truncated every export to the first 100 rows (Mile, 2026-10: orders
    // export only returned the first page once the list grew past 100).
    public const int MaxPageSize = 10000;
    public int GetPageSize() => PageSize < 1 ? 20 : PageSize > MaxPageSize ? MaxPageSize : PageSize;

    public DateTime? GetCreatedFromUtc() =>
        CreatedFrom.HasValue ? DateTime.SpecifyKind(CreatedFrom.Value.Date, DateTimeKind.Utc) : null;

    public DateTime? GetCreatedToUtc() =>
        CreatedTo.HasValue ? DateTime.SpecifyKind(CreatedTo.Value.Date, DateTimeKind.Utc) : null;
}
