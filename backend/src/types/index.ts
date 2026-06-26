export type PaginationParams = {
  page: number;
  limit: number;
  skip: number;
};

export type PaginatedResult<T> = {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type ApiResponse<T = unknown> = {
  success: boolean;
  message: string;
  data?: T;
  error?: string;
  pagination?: PaginatedResult<unknown>['pagination'];
};

export type SortParams = {
  sortBy: string;
  sortOrder: 'asc' | 'desc';
};

export type FilterParams = Record<string, string | number | boolean>;

export type SearchParams = {
  search?: string;
  searchFields?: string[];
};

export type QueryParams = PaginationParams & SortParams & FilterParams & SearchParams;