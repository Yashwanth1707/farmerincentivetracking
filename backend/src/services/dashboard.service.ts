import prisma from '../utils/prisma';

export class DashboardService {
  async getStats(financialYearId?: string) {
    // Get active financial year if not specified
    let fyId = financialYearId;
    if (!fyId) {
      const activeFy = await prisma.financialYear.findFirst({
        where: { isActive: true, isClosed: false },
      });
      if (activeFy) fyId = activeFy.id;
    }

    const whereFy = fyId ? { financialYearId: fyId } : {};

    // Farmers count
    const [totalFarmers, activeFarmers] = await Promise.all([
      prisma.farmer.count(),
      prisma.farmer.count({ where: { isActive: true } }),
    ]);

    // Payment stats for FY
    const paymentAgg = await prisma.payment.aggregate({
      where: whereFy,
      _sum: { grossAmount: true, tdsAmount: true, netAmount: true },
      _count: true,
    });

    // Batch stats
    const [totalBatches, approvedBatches, pendingBatches] = await Promise.all([
      prisma.paymentBatch.count({ where: whereFy }),
      prisma.paymentBatch.count({ where: { ...whereFy, status: 'APPROVED' } }),
      prisma.paymentBatch.count({ where: { ...whereFy, status: { in: ['DRAFT', 'PENDING_APPROVAL'] } } }),
    ]);

    // Farmers with pending TDS decisions
    const pendingTds = await prisma.payment.count({
      where: { ...whereFy, isTdsDecisionPending: true },
    });

    // Recent batches
    const recentBatches = await prisma.paymentBatch.findMany({
      where: whereFy,
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: {
        financialYear: { select: { yearLabel: true } },
        processedByUser: { select: { fullName: true } },
        _count: { select: { batchDetails: true } },
      },
    });

    // Village-wise stats
    const villageStats = await prisma.farmer.groupBy({
      by: ['village'],
      where: { isActive: true },
      _count: true,
      orderBy: { _count: { id: 'desc' } },
      take: 10,
    });

    // SMS stats
    const smsStats = await prisma.smsLog.groupBy({
      by: ['status'],
      _count: true,
    });

    return {
      farmers: {
        total: totalFarmers,
        active: activeFarmers,
      },
      payments: {
        total: paymentAgg._count,
        totalGross: Number(paymentAgg._sum.grossAmount || 0),
        totalTds: Number(paymentAgg._sum.tdsAmount || 0),
        totalNet: Number(paymentAgg._sum.netAmount || 0),
      },
      batches: {
        total: totalBatches,
        approved: approvedBatches,
        pending: pendingBatches,
      },
      pendingTds,
      recentBatches,
      topVillages: villageStats,
      smsStats: smsStats.reduce((acc: Record<string, number>, s) => {
        acc[s.status] = s._count;
        return acc;
      }, {}),
    };
  }
}

export const dashboardService = new DashboardService();