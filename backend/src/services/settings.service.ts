import prisma from '../utils/prisma';
import { NotFoundError } from '../utils/errors';

export class SettingsService {
  /**
   * Get all settings
   */
  async getAll() {
    const settings = await prisma.setting.findMany({
      orderBy: { category: 'asc' },
    });

    // Group by category
    const grouped: Record<string, any> = {};
    for (const setting of settings) {
      if (!grouped[setting.category]) grouped[setting.category] = {};
      // Try parsing JSON value
      try {
        grouped[setting.category][setting.key] = JSON.parse(setting.value);
      } catch {
        grouped[setting.category][setting.key] = setting.value;
      }
    }

    return grouped;
  }

  /**
   * Get a single setting by key
   */
  async getByKey(key: string) {
    const setting = await prisma.setting.findUnique({ where: { key } });
    if (!setting) throw new NotFoundError(`Setting ${key}`);

    try {
      return { key, value: JSON.parse(setting.value), category: setting.category };
    } catch {
      return { key, value: setting.value, category: setting.category };
    }
  }

  /**
   * Update or create a setting
   */
  async set(key: string, value: any, category: string = 'general') {
    const stringValue = typeof value === 'object' ? JSON.stringify(value) : String(value);

    return prisma.setting.upsert({
      where: { key },
      update: { value: stringValue, category },
      create: { key, value: stringValue, category },
    });
  }

  /**
   * Update multiple settings at once
   */
  async updateMany(settings: Record<string, any>, category?: string) {
    const results = [];
    for (const [key, value] of Object.entries(settings)) {
      const result = await this.set(key, value, category || 'general');
      results.push(result);
    }
    return results;
  }

  /**
   * Get settings for a specific category
   */
  async getByCategory(category: string) {
    const settings = await prisma.setting.findMany({
      where: { category },
      orderBy: { key: 'asc' },
    });

    const result: Record<string, any> = {};
    for (const setting of settings) {
      try {
        result[setting.key] = JSON.parse(setting.value);
      } catch {
        result[setting.key] = setting.value;
      }
    }

    return result;
  }
}

export const settingsService = new SettingsService();