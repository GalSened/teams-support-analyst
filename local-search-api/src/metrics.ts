/**
 * Metrics collection and monitoring for LocalSearch API
 */

export interface MetricsData {
  uptime: number;
  requests: {
    total: number;
    byEndpoint: Record<string, number>;
    byStatus: Record<number, number>;
  };
  search: {
    totalSearches: number;
    averageResponseTime: number;
    totalResults: number;
    failedSearches: number;
    cacheHits: number;
  };
  file: {
    totalReads: number;
    averageResponseTime: number;
    failedReads: number;
  };
  errors: {
    total: number;
    recent: Array<{ timestamp: string; error: string; endpoint: string }>;
  };
}

class MetricsCollector {
  private startTime: number;
  private metrics: MetricsData;
  private searchResponseTimes: number[] = [];
  private fileResponseTimes: number[] = [];
  private readonly MAX_RECENT_ERRORS = 50;
  private readonly MAX_RESPONSE_TIMES = 100;

  constructor() {
    this.startTime = Date.now();
    this.metrics = {
      uptime: 0,
      requests: {
        total: 0,
        byEndpoint: {},
        byStatus: {}
      },
      search: {
        totalSearches: 0,
        averageResponseTime: 0,
        totalResults: 0,
        failedSearches: 0,
        cacheHits: 0
      },
      file: {
        totalReads: 0,
        averageResponseTime: 0,
        failedReads: 0
      },
      errors: {
        total: 0,
        recent: []
      }
    };
  }

  /**
   * Record a request
   */
  recordRequest(endpoint: string, statusCode: number): void {
    this.metrics.requests.total++;
    this.metrics.requests.byEndpoint[endpoint] =
      (this.metrics.requests.byEndpoint[endpoint] || 0) + 1;
    this.metrics.requests.byStatus[statusCode] =
      (this.metrics.requests.byStatus[statusCode] || 0) + 1;
  }

  /**
   * Record a search operation
   */
  recordSearch(responseTime: number, resultCount: number, success: boolean): void {
    this.metrics.search.totalSearches++;

    if (success) {
      this.searchResponseTimes.push(responseTime);
      if (this.searchResponseTimes.length > this.MAX_RESPONSE_TIMES) {
        this.searchResponseTimes.shift();
      }

      this.metrics.search.totalResults += resultCount;
      this.metrics.search.averageResponseTime =
        this.searchResponseTimes.reduce((a, b) => a + b, 0) / this.searchResponseTimes.length;
    } else {
      this.metrics.search.failedSearches++;
    }
  }

  /**
   * Record a file operation
   */
  recordFileRead(responseTime: number, success: boolean): void {
    this.metrics.file.totalReads++;

    if (success) {
      this.fileResponseTimes.push(responseTime);
      if (this.fileResponseTimes.length > this.MAX_RESPONSE_TIMES) {
        this.fileResponseTimes.shift();
      }

      this.metrics.file.averageResponseTime =
        this.fileResponseTimes.reduce((a, b) => a + b, 0) / this.fileResponseTimes.length;
    } else {
      this.metrics.file.failedReads++;
    }
  }

  /**
   * Record an error
   */
  recordError(error: string, endpoint: string): void {
    this.metrics.errors.total++;
    this.metrics.errors.recent.unshift({
      timestamp: new Date().toISOString(),
      error,
      endpoint
    });

    // Keep only recent errors
    if (this.metrics.errors.recent.length > this.MAX_RECENT_ERRORS) {
      this.metrics.errors.recent.pop();
    }
  }

  /**
   * Record cache hit
   */
  recordCacheHit(): void {
    this.metrics.search.cacheHits++;
  }

  /**
   * Get current metrics
   */
  getMetrics(): MetricsData {
    return {
      ...this.metrics,
      uptime: Math.floor((Date.now() - this.startTime) / 1000)
    };
  }

  /**
   * Get health status
   */
  getHealthStatus(): {
    status: 'healthy' | 'degraded' | 'unhealthy';
    checks: Record<string, { status: string; message?: string }>;
  } {
    const metrics = this.getMetrics();
    const checks: Record<string, { status: string; message?: string }> = {};

    // Check error rate
    const errorRate = metrics.requests.total > 0
      ? metrics.errors.total / metrics.requests.total
      : 0;

    checks.errorRate = errorRate < 0.05
      ? { status: 'pass' }
      : { status: 'warn', message: `Error rate: ${(errorRate * 100).toFixed(2)}%` };

    // Check search success rate
    const searchSuccessRate = metrics.search.totalSearches > 0
      ? 1 - (metrics.search.failedSearches / metrics.search.totalSearches)
      : 1;

    checks.searchSuccess = searchSuccessRate > 0.9
      ? { status: 'pass' }
      : { status: 'warn', message: `Search success: ${(searchSuccessRate * 100).toFixed(2)}%` };

    // Check average response time
    checks.responseTime = metrics.search.averageResponseTime < 2000
      ? { status: 'pass' }
      : { status: 'warn', message: `Slow response: ${metrics.search.averageResponseTime.toFixed(0)}ms` };

    // Overall status
    const hasWarnings = Object.values(checks).some(c => c.status === 'warn');
    const hasFails = Object.values(checks).some(c => c.status === 'fail');

    const status = hasFails ? 'unhealthy' : hasWarnings ? 'degraded' : 'healthy';

    return { status, checks };
  }

  /**
   * Reset metrics
   */
  reset(): void {
    this.startTime = Date.now();
    this.searchResponseTimes = [];
    this.fileResponseTimes = [];
    this.metrics = {
      uptime: 0,
      requests: {
        total: 0,
        byEndpoint: {},
        byStatus: {}
      },
      search: {
        totalSearches: 0,
        averageResponseTime: 0,
        totalResults: 0,
        failedSearches: 0,
        cacheHits: 0
      },
      file: {
        totalReads: 0,
        averageResponseTime: 0,
        failedReads: 0
      },
      errors: {
        total: 0,
        recent: []
      }
    };
  }
}

// Singleton instance
export const metricsCollector = new MetricsCollector();
