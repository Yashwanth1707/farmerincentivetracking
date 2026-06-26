import prisma from '../utils/prisma';
import { NotFoundError, ValidationError } from '../utils/errors';
import { config } from '../config';
import { PaginatedResult } from '../types';
import logger from '../utils/logger';

export class SmsService {
  /**
   * Send SMS via Twilio (or log in dev)
   */
  private async sendViaTwilio(to: string, message: string): Promise<{ success: boolean; sid?: string; error?: string }> {
    if (config.nodeEnv === 'development' || !config.twilio.accountSid) {
      logger.info({ to, message }, '[DEV] SMS would be sent');
      return { success: true, sid: `dev-${Date.now()}` };
    }

    try {
      const twilio = require('twilio');
      const client = twilio(config.twilio.accountSid, config.twilio.authToken);
      const result = await client.messages.create({
        body: message,
        from: config.twilio.phoneNumber,
        to,
      });
      return { success: true, sid: result.sid };
    } catch (error: any) {
      logger.error({ error, to }, 'Twilio SMS failed');
      return { success: false, error: error.message };
    }
  }

  /**
   * Render template with variables
   */
  renderTemplate(template: string, variables: Record<string, string | number>): string {
    let rendered = template;
    for (const [key, value] of Object.entries(variables)) {
      rendered = rendered.replace(new RegExp(`\\{\\{\\s*${key}\\s*\\}\\}`, 'g'), String(value));
    }
    return rendered;
  }

  /**
   * Send SMS to a single farmer
   */
  async sendSingleSms(farmerId: string, templateId: string, sentBy: string, customMessage?: string) {
    const farmer = await prisma.farmer.findUnique({ where: { id: farmerId } });
    if (!farmer) throw new NotFoundError('Farmer');
    if (!farmer.phone) throw new ValidationError({ phone: ['Farmer has no phone number'] });

    let message: string;

    if (customMessage) {
      message = this.renderTemplate(customMessage, {
        FarmerName: farmer.name,
        FarmerID: farmer.farmerId,
        Village: farmer.village,
      });
    } else {
      const template = await prisma.smsTemplate.findUnique({ where: { id: templateId } });
      if (!template) throw new NotFoundError('SMS template');

      message = this.renderTemplate(template.body, {
        FarmerName: farmer.name,
        FarmerID: farmer.farmerId,
        Village: farmer.village,
      });
    }

    const result = await this.sendViaTwilio(farmer.phone, message);

    // Log the SMS
    await prisma.smsLog.create({
      data: {
        sentById: sentBy,
        farmerId,
        templateId: customMessage ? undefined : templateId,
        recipient: farmer.phone,
        message,
        status: result.success ? 'SENT' : 'FAILED',
        twilioSid: result.sid,
        errorMsg: result.error,
        sentAt: new Date(),
      },
    });

    return { message, status: result.success ? 'SENT' : 'FAILED', farmerName: farmer.name };
  }

  /**
   * Send bulk SMS to farmers in a batch
   */
  async sendBatchSms(batchId: string, templateId: string, sentBy: string) {
    const batch = await prisma.paymentBatch.findUnique({
      where: { id: batchId },
      include: {
        batchDetails: {
          include: {
            farmer: true,
            payment: true,
          },
        },
      },
    });

    if (!batch) throw new NotFoundError('Batch');

    const template = await prisma.smsTemplate.findUnique({ where: { id: templateId } });
    if (!template) throw new NotFoundError('SMS template');

    const results = [];
    for (const detail of batch.batchDetails) {
      if (!detail.farmer.phone) continue;

      const message = this.renderTemplate(template.body, {
        FarmerName: detail.farmer.name,
        FarmerID: detail.farmer.farmerId,
        Amount: Number(detail.payment.netAmount).toFixed(2),
        Village: detail.farmer.village,
        PaymentDate: batch.paymentDate?.toLocaleDateString() || '',
        ReferenceNumber: `BATCH-${batch.batchNumber}`,
      });

      const result = await this.sendViaTwilio(detail.farmer.phone, message);

      await prisma.smsLog.create({
        data: {
          sentById: sentBy,
          batchId,
          farmerId: detail.farmer.id,
          templateId,
          recipient: detail.farmer.phone,
          message,
          status: result.success ? 'SENT' : 'FAILED',
          twilioSid: result.sid,
          errorMsg: result.error,
          sentAt: new Date(),
        },
      });

      results.push({
        farmerName: detail.farmer.name,
        phone: detail.farmer.phone,
        status: result.success ? 'SENT' : 'FAILED',
      });
    }

    return results;
  }

  /**
   * Preview SMS message
   */
  async previewSms(farmerId: string, templateId: string, customMessage?: string) {
    const farmer = await prisma.farmer.findUnique({ where: { id: farmerId } });
    if (!farmer) throw new NotFoundError('Farmer');

    let message: string;

    if (customMessage) {
      message = this.renderTemplate(customMessage, {
        FarmerName: farmer.name,
        FarmerID: farmer.farmerId,
        Village: farmer.village,
      });
    } else {
      const template = await prisma.smsTemplate.findUnique({ where: { id: templateId } });
      if (!template) throw new NotFoundError('SMS template');

      message = this.renderTemplate(template.body, {
        FarmerName: farmer.name,
        FarmerID: farmer.farmerId,
        Village: farmer.village,
      });
    }

    return { message, recipient: farmer.phone, farmerName: farmer.name };
  }

  /**
   * List SMS logs with pagination
   */
  async listLogs(params: {
    page?: number;
    limit?: number;
    status?: string;
  }): Promise<PaginatedResult<any>> {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;
    const where: any = {};

    if (params.status) where.status = params.status;

    const [data, total] = await Promise.all([
      prisma.smsLog.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          sentBy: { select: { id: true, fullName: true } },
        },
      }),
      prisma.smsLog.count({ where }),
    ]);

    return {
      data,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /**
   * Get all SMS templates
   */
  async getTemplates() {
    return prisma.smsTemplate.findMany({
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Create SMS template
   */
  async createTemplate(data: { name: string; body: string }) {
    return prisma.smsTemplate.create({ data });
  }

  /**
   * Update SMS template
   */
  async updateTemplate(id: string, data: { name?: string; body?: string; isActive?: boolean }) {
    const template = await prisma.smsTemplate.findUnique({ where: { id } });
    if (!template) throw new NotFoundError('SMS template');

    return prisma.smsTemplate.update({ where: { id }, data });
  }
}

export const smsService = new SmsService();