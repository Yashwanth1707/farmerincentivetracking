import session from 'express-session';
import prisma from './prisma';

const Store = session.Store;

export class PrismaSessionStore extends Store {
  get(sid: string, callback: (err: any, session?: session.SessionData | null) => void): void {
    prisma.session.findUnique({ where: { sid } })
      .then((record) => {
        if (!record || record.expire <= new Date()) {
          if (record) {
            void prisma.session.delete({ where: { sid } }).catch(() => undefined);
          }
          callback(null, null);
          return;
        }

        callback(null, record.sess as unknown as session.SessionData);
      })
      .catch((error) => callback(error));
  }

  set(sid: string, sessionData: session.SessionData, callback?: (err?: any) => void): void {
    const maxAge = sessionData.cookie?.maxAge ?? 24 * 60 * 60 * 1000;
    const expire = new Date(Date.now() + maxAge);

    prisma.session.upsert({
      where: { sid },
      update: {
        sess: sessionData as any,
        expire,
      },
      create: {
        sid,
        sess: sessionData as any,
        expire,
      },
    })
      .then(() => callback?.())
      .catch((error) => callback?.(error));
  }

  destroy(sid: string, callback?: (err?: any) => void): void {
    prisma.session.deleteMany({ where: { sid } })
      .then(() => callback?.())
      .catch((error) => callback?.(error));
  }

  touch(sid: string, sessionData: session.SessionData, callback?: (err?: any) => void): void {
    const maxAge = sessionData.cookie?.maxAge ?? 24 * 60 * 60 * 1000;

    prisma.session.update({
      where: { sid },
      data: {
        expire: new Date(Date.now() + maxAge),
        sess: sessionData as any,
      },
    })
      .then(() => callback?.())
      .catch((error) => callback?.(error));
  }
}
