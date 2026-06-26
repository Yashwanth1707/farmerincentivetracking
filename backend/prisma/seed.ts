import { PrismaClient, UserRole, BatchStatus, TdsDecision, SmsStatus } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { Decimal } from '@prisma/client/runtime/library';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting seed...\n');

  // Clean existing data
  await prisma.sentSmsRecord.deleteMany();
  await prisma.smsLog.deleteMany();
  await prisma.batchDetail.deleteMany();
  await prisma.paymentBatch.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.tdsRecord.deleteMany();
  await prisma.auditLog.deleteMany();
  await prisma.passwordReset.deleteMany();
  await prisma.setting.deleteMany();
  await prisma.smsTemplate.deleteMany();
  await prisma.financialYear.deleteMany();
  await prisma.farmer.deleteMany();
  await prisma.user.deleteMany();

  console.log('Cleaned existing data.\n');

  // ── Create Users ─────────────────────────────────────────────────────────────
  const passwordHash = await bcrypt.hash('password123', 12);
  const users = await Promise.all([
    prisma.user.create({
      data: {
        username: 'admin',
        email: 'admin@fims.com',
        passwordHash,
        fullName: 'System Administrator',
        phone: '9999999991',
        role: UserRole.ADMIN,
      },
    }),
    prisma.user.create({
      data: {
        username: 'admin2',
        email: 'admin2@fims.com',
        passwordHash,
        fullName: 'Secondary Admin',
        phone: '9999999992',
        role: UserRole.ADMIN,
      },
    }),
    prisma.user.create({
      data: {
        username: 'operator1',
        email: 'operator1@fims.com',
        passwordHash,
        fullName: 'Ramesh Kumar',
        phone: '9999999993',
        role: UserRole.OPERATOR,
      },
    }),
    prisma.user.create({
      data: {
        username: 'operator2',
        email: 'operator2@fims.com',
        passwordHash,
        fullName: 'Suresh Reddy',
        phone: '9999999994',
        role: UserRole.OPERATOR,
      },
    }),
    prisma.user.create({
      data: {
        username: 'operator3',
        email: 'operator3@fims.com',
        passwordHash,
        fullName: 'Priya Sharma',
        phone: '9999999995',
        role: UserRole.OPERATOR,
      },
    }),
    prisma.user.create({
      data: {
        username: 'viewer1',
        email: 'viewer1@fims.com',
        passwordHash,
        fullName: 'Venkatesh Rao',
        phone: '9999999996',
        role: UserRole.VIEWER,
      },
    }),
    prisma.user.create({
      data: {
        username: 'viewer2',
        email: 'viewer2@fims.com',
        passwordHash,
        fullName: 'Lakshmi Devi',
        phone: '9999999997',
        role: UserRole.VIEWER,
      },
    }),
    prisma.user.create({
      data: {
        username: 'operator4',
        email: 'operator4@fims.com',
        passwordHash,
        fullName: 'Mohan Das',
        phone: '9999999998',
        role: UserRole.OPERATOR,
      },
    }),
    prisma.user.create({
      data: {
        username: 'operator5',
        email: 'operator5@fims.com',
        passwordHash,
        fullName: 'Anita Patel',
        phone: '9999999999',
        role: UserRole.OPERATOR,
      },
    }),
    prisma.user.create({
      data: {
        username: 'viewer3',
        email: 'viewer3@fims.com',
        passwordHash,
        fullName: 'Gopal Krishnan',
        phone: '9999999910',
        role: UserRole.VIEWER,
      },
    }),
  ]);

  console.log(`✅ Created ${users.length} users`);
  console.log('   Default password for all users: password123\n');

  // ── Create Financial Years ───────────────────────────────────────────────────
  const fy2024 = await prisma.financialYear.create({
    data: {
      yearLabel: '2024-2025',
      startDate: new Date('2024-04-01'),
      endDate: new Date('2025-03-31'),
      isActive: true,
      isClosed: false,
      createdBy: users[0].id,
      updatedBy: users[0].id,
    },
  });

  const fy2023 = await prisma.financialYear.create({
    data: {
      yearLabel: '2023-2024',
      startDate: new Date('2023-04-01'),
      endDate: new Date('2024-03-31'),
      isActive: false,
      isClosed: true,
      createdBy: users[0].id,
      updatedBy: users[0].id,
    },
  });

  console.log('✅ Created 2 financial years (2023-2024, 2024-2025)\n');

  // ── Create Farmers (100) ────────────────────────────────────────────────────
  const villages = [
    'Gopalpally', 'Rampur', 'Shivnagar', 'Krishna Puram', 'Laxmipur',
    'Hanumannagar', 'Venkatapuram', 'Suryapet', 'Narsapur', 'Bheemgal',
  ];
  const districts = ['Warangal', 'Hanamkonda', 'Karimnagar', 'Nalgonda', 'Khammam'];
  const banks = ['State Bank of India', 'Canara Bank', 'Union Bank', 'HDFC Bank', 'ICICI Bank'];

  const admins = [users[0], users[1]];
  const operators = [users[2], users[3], users[4], users[7], users[8]];

  const farmers = [];
  for (let i = 1; i <= 100; i++) {
    const creator = i <= 50 ? admins[i % admins.length] : operators[i % operators.length];
    const village = villages[Math.floor(Math.random() * villages.length)];
    const district = districts[Math.floor(Math.random() * districts.length)];
    const bank = banks[Math.floor(Math.random() * banks.length)];

    const farmer = await prisma.farmer.create({
      data: {
        farmerId: `FARM${String(i).padStart(4, '0')}`,
        aadharNumber: i <= 80 ? `${100000000000 + i}` : null,
        name: `Farmer ${i}`,
        fatherName: i % 3 === 0 ? `Father of Farmer ${i}` : null,
        village,
        district,
        state: 'Telangana',
        pincode: String(506000 + Math.floor(Math.random() * 100)),
        phone: `987654${String(3000 + i).slice(-4)}`,
        bankName: bank,
        branchName: `${village} Branch`,
        accountNumber: `ACC${String(1000000 + i)}`,
        ifscCode: `${bank.substring(0, 4).toUpperCase()}000${String(1000 + Math.floor(i / 10))}`,
        isActive: i <= 95,
        createdBy: creator.id,
        updatedBy: creator.id,
      },
    });
    farmers.push(farmer);
  }

  console.log(`✅ Created ${farmers.length} farmers\n`);

  // ── Create Payments ─────────────────────────────────────────────────────────
  const paymentsFy24 = [];
  for (let i = 0; i < 50; i++) {
    const farmer = farmers[i];
    const grossAmount = Math.round((Math.random() * 80000 + 5000) * 100) / 100;
    const tdsApplicable = i < 10; // First 10 farmers have TDS
    const tdsPercentage = tdsApplicable ? 10 : 0;
    const tdsAmount = tdsApplicable ? Math.round(grossAmount * 0.1 * 100) / 100 : 0;
    const netAmount = grossAmount - tdsAmount;

    const payment = await prisma.payment.create({
      data: {
        farmerId: farmer.id,
        financialYearId: fy2024.id,
        invoiceNumber: i % 2 === 0 ? `INV-2024-${String(i + 1).padStart(4, '0')}` : null,
        grossAmount: new Decimal(grossAmount),
        tdsAmount: new Decimal(tdsAmount),
        netAmount: new Decimal(netAmount),
        tdsApplicable,
        tdsPercentage: tdsApplicable ? new Decimal(tdsPercentage) : null,
        paymentDate: new Date('2024-07-01'),
        notes: i % 5 === 0 ? `Seed incentive for kharif season` : null,
      },
    });
    paymentsFy24.push(payment);
  }

  // Add some payments with pending TDS decisions
  for (let i = 50; i < 60; i++) {
    const farmer = farmers[i];
    const grossAmount = Math.round((Math.random() * 50000 + 100000) * 100) / 100;

    const payment = await prisma.payment.create({
      data: {
        farmerId: farmer.id,
        financialYearId: fy2024.id,
        grossAmount: new Decimal(grossAmount),
        tdsAmount: new Decimal(0),
        netAmount: new Decimal(grossAmount),
        tdsApplicable: false,
        isTdsDecisionPending: true,
        notes: 'TDS decision pending - cumulative crossed threshold',
      },
    });
    paymentsFy24.push(payment);
  }

  console.log(`✅ Created ${paymentsFy24.length} payments for 2024-2025\n`);

  // ── Create TDS Records ──────────────────────────────────────────────────────
  for (let i = 0; i < 10; i++) {
    const farmer = farmers[i];
    const cumulativeResult = await prisma.payment.aggregate({
      where: { farmerId: farmer.id, financialYearId: fy2024.id },
      _sum: { grossAmount: true },
    });

    await prisma.tdsRecord.create({
      data: {
        farmerId: farmer.id,
        financialYearId: fy2024.id,
        cumulativeAmount: new Decimal(Number(cumulativeResult._sum.grossAmount || 0)),
        decision: i % 2 === 0 ? TdsDecision.YES : TdsDecision.NO,
        decidedBy: users[0].id,
        decidedAt: new Date(),
        notes: i % 2 === 0 ? 'TDS applicable as cumulative exceeds threshold' : 'TDS not applicable - exempted',
      },
    });
  }

  console.log('✅ Created TDS records for threshold-crossed farmers\n');

  // ── Create Payment Batches ──────────────────────────────────────────────────
  const batch1Payments = paymentsFy24.slice(0, 10);
  const batch1Gross = batch1Payments.reduce((sum, p) => sum + Number(p.grossAmount), 0);
  const batch1Tds = batch1Payments.reduce((sum, p) => sum + Number(p.tdsAmount), 0);
  const batch1Net = batch1Payments.reduce((sum, p) => sum + Number(p.netAmount), 0);

  const batch1 = await prisma.paymentBatch.create({
    data: {
      batchNumber: 'BATCH-2024-0001',
      financialYearId: fy2024.id,
      totalFarmers: batch1Payments.length,
      totalGrossAmount: new Decimal(batch1Gross),
      totalTdsAmount: new Decimal(batch1Tds),
      totalNetAmount: new Decimal(batch1Net),
      status: BatchStatus.APPROVED,
      processedBy: users[2].id,
      approvedBy: users[0].id,
      approvedAt: new Date('2024-07-15'),
      paymentDate: new Date('2024-07-20'),
      notes: 'First batch - Kharif incentives',
      batchDetails: {
        create: batch1Payments.map(p => ({
          paymentId: p.id,
          farmerId: p.farmerId,
        })),
      },
    },
  });

  const batch2Payments = paymentsFy24.slice(10, 25);
  const batch2Gross = batch2Payments.reduce((sum, p) => sum + Number(p.grossAmount), 0);
  const batch2Tds = batch2Payments.reduce((sum, p) => sum + Number(p.tdsAmount), 0);
  const batch2Net = batch2Payments.reduce((sum, p) => sum + Number(p.netAmount), 0);

  const batch2 = await prisma.paymentBatch.create({
    data: {
      batchNumber: 'BATCH-2024-0002',
      financialYearId: fy2024.id,
      totalFarmers: batch2Payments.length,
      totalGrossAmount: new Decimal(batch2Gross),
      totalTdsAmount: new Decimal(batch2Tds),
      totalNetAmount: new Decimal(batch2Net),
      status: BatchStatus.DRAFT,
      processedBy: users[3].id,
      notes: 'Second batch - pending approval',
      batchDetails: {
        create: batch2Payments.map(p => ({
          paymentId: p.id,
          farmerId: p.farmerId,
        })),
      },
    },
  });

  const batch3Payments = paymentsFy24.slice(25, 40);
  const batch3Gross = batch3Payments.reduce((sum, p) => sum + Number(p.grossAmount), 0);
  const batch3Tds = batch3Payments.reduce((sum, p) => sum + Number(p.tdsAmount), 0);
  const batch3Net = batch3Payments.reduce((sum, p) => sum + Number(p.netAmount), 0);

  const batch3 = await prisma.paymentBatch.create({
    data: {
      batchNumber: 'BATCH-2024-0003',
      financialYearId: fy2024.id,
      totalFarmers: batch3Payments.length,
      totalGrossAmount: new Decimal(batch3Gross),
      totalTdsAmount: new Decimal(batch3Tds),
      totalNetAmount: new Decimal(batch3Net),
      status: BatchStatus.PAID,
      processedBy: users[2].id,
      approvedBy: users[0].id,
      approvedAt: new Date('2024-08-01'),
      paymentDate: new Date('2024-08-05'),
      notes: 'Third batch - paid successfully',
      batchDetails: {
        create: batch3Payments.map(p => ({
          paymentId: p.id,
          farmerId: p.farmerId,
        })),
      },
    },
  });

  console.log('✅ Created 3 payment batches (1 approved, 1 draft, 1 paid)\n');

  // ── Create SMS Templates ───────────────────────────────────────────────────
  const smsTemplates = await Promise.all([
    prisma.smsTemplate.create({
      data: {
        name: 'Payment Confirmation',
        body: 'Dear {{FarmerName}}, your incentive payment of ₹{{Amount}} has been credited to your account. Ref: {{ReferenceNumber}}. - FIMS',
        isActive: true,
      },
    }),
    prisma.smsTemplate.create({
      data: {
        name: 'Batch Processing Alert',
        body: 'Dear {{FarmerName}}, your payment batch is being processed. Amount: ₹{{Amount}}, Date: {{PaymentDate}}. - FIMS',
        isActive: true,
      },
    }),
    prisma.smsTemplate.create({
      data: {
        name: 'TDS Notification',
        body: 'Dear {{FarmerName}}, TDS has been deducted from your incentive of ₹{{Amount}}. Net payable: ₹{{NetAmount}}. - FIMS',
        isActive: true,
      },
    }),
    prisma.smsTemplate.create({
      data: {
        name: 'Welcome Message',
        body: 'Welcome {{FarmerName}}! You have been registered in FIMS. Your Farmer ID is {{FarmerID}}. Village: {{Village}}. - FIMS',
        isActive: true,
      },
    }),
    prisma.smsTemplate.create({
      data: {
        name: 'Payment Reminder',
        body: 'Reminder: {{FarmerName}}, please collect your incentive payment of ₹{{Amount}} from the village office. - FIMS',
        isActive: false,
      },
    }),
  ]);

  console.log(`✅ Created ${smsTemplates.length} SMS templates\n`);

  // ── Create Settings ─────────────────────────────────────────────────────────
  await Promise.all([
    prisma.setting.create({ data: { key: 'tds_percentage', value: '10', category: 'tds' } }),
    prisma.setting.create({ data: { key: 'tds_threshold', value: '100000', category: 'tds' } }),
    prisma.setting.create({ data: { key: 'app_name', value: '"Farmer Incentive Management System"', category: 'general' } }),
    prisma.setting.create({ data: { key: 'company_name', value: '"Akshaya Ginning Mill"', category: 'general' } }),
    prisma.setting.create({ data: { key: 'sms_enabled', value: 'true', category: 'sms' } }),
    prisma.setting.create({ data: { key: 'max_sms_per_day', value: '500', category: 'sms' } }),
    prisma.setting.create({ data: { key: 'currency', value: '"INR"', category: 'payment' } }),
    prisma.setting.create({ data: { key: 'payment_modes', value: '["Bank Transfer","Cheque","Cash"]', category: 'payment' } }),
  ]);

  console.log('✅ Created settings (TDS, general, SMS, payment)\n');

  // ── Create Sample SMS Logs ─────────────────────────────────────────────────
  const sampleLogs = [
    { farmerId: farmers[0].id, batchId: batch1.id, templateId: smsTemplates[0].id, recipient: farmers[0].phone!, message: 'Dear Farmer 1, your incentive payment of ₹50000.00 has been credited...', status: SmsStatus.DELIVERED },
    { farmerId: farmers[1].id, batchId: batch1.id, templateId: smsTemplates[0].id, recipient: farmers[1].phone!, message: 'Dear Farmer 2, your incentive payment of ₹35000.00 has been credited...', status: SmsStatus.SENT },
    { farmerId: farmers[2].id, batchId: batch2.id, templateId: smsTemplates[1].id, recipient: farmers[2].phone!, message: 'Dear Farmer 3, your payment batch is being processed...', status: SmsStatus.QUEUED },
  ];

  for (const log of sampleLogs) {
    await prisma.smsLog.create({
      data: {
        sentById: users[2].id,
        ...log,
        sentAt: new Date(),
      },
    });
  }

  console.log('✅ Created sample SMS logs\n');

  // ── Create Audit Logs ─────────────────────────────────────────────────────
  const auditActions = [
    { userId: users[0].id, action: 'LOGIN', entity: 'auth', entityId: users[0].id, ipAddress: '127.0.0.1' },
    { userId: users[2].id, action: 'LOGIN', entity: 'auth', entityId: users[2].id, ipAddress: '192.168.1.100' },
    { userId: users[2].id, action: 'CREATE_BATCH', entity: 'payment_batch', entityId: batch1.id, ipAddress: '192.168.1.100' },
    { userId: users[0].id, action: 'APPROVE_BATCH', entity: 'payment_batch', entityId: batch1.id, ipAddress: '127.0.0.1' },
    { userId: users[3].id, action: 'UPLOAD_PAYMENT', entity: 'payment', entityId: paymentsFy24[0].id, ipAddress: '192.168.1.101' },
    { userId: users[4].id, action: 'CREATE_FARMER', entity: 'farmer', entityId: farmers[90].id, ipAddress: '192.168.1.102' },
    { userId: users[0].id, action: 'SETTINGS_UPDATE', entity: 'settings', entityId: 'tds_percentage', ipAddress: '127.0.0.1' },
  ];

  for (const log of auditActions) {
    await prisma.auditLog.create({
      data: {
        ...log,
        userAgent: 'Mozilla/5.0 Seed Script',
        createdAt: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000),
      },
    });
  }

  console.log('✅ Created audit logs\n');

  console.log('🎉 Seed completed successfully!');
  console.log('\n📋 Summary:');
  console.log('   - 10 users (2 Admin, 5 Operator, 3 Viewer)');
  console.log('   - 100 farmers (95 active, 5 inactive)');
  console.log('   - 2 financial years');
  console.log('   - 60 payments in FY 2024-2025');
  console.log('   - 10 TDS records');
  console.log('   - 3 payment batches');
  console.log('   - 5 SMS templates');
  console.log('   - 8 settings');
  console.log('   - Sample SMS logs & audit logs');
  console.log('\n🔑 Default password for all users: password123');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });