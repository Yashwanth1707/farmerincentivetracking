import { PrismaClient, UserRole } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const sampleUsers = [
  {
    username: 'admin',
    email: 'admin@fims.com',
    fullName: 'System Administrator',
    phone: '9999999991',
    role: UserRole.ADMIN,
  },
  {
    username: 'operator1',
    email: 'operator1@fims.com',
    fullName: 'Ramesh Kumar',
    phone: '9999999993',
    role: UserRole.OPERATOR,
  },
  {
    username: 'operator2',
    email: 'operator2@fims.com',
    fullName: 'Suresh Reddy',
    phone: '9999999994',
    role: UserRole.OPERATOR,
  },
  {
    username: 'viewer1',
    email: 'viewer1@fims.com',
    fullName: 'Venkatesh Rao',
    phone: '9999999996',
    role: UserRole.VIEWER,
  },
];

async function main() {
  const passwordHash = await bcrypt.hash('password123', 12);

  for (const user of sampleUsers) {
    await prisma.user.upsert({
      where: { username: user.username },
      update: {
        email: user.email,
        fullName: user.fullName,
        phone: user.phone,
        role: user.role,
        isActive: true,
      },
      create: {
        ...user,
        passwordHash,
        isActive: true,
      },
    });
  }

  console.log(`Seeded ${sampleUsers.length} sample users.`);
  console.log('Default password: password123');
}

main()
  .catch((error) => {
    console.error('User seed failed:', error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
