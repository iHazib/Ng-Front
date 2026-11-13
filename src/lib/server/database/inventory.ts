import 'server-only';
import { authorizeAdmin } from './client';

function orderId(value: string) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) throw new Error('Invalid order identifier.');
  return value;
}

/** Database primitives only: no checkout route, payment, or courier operation. */
export async function reserveOrder(token: string, order: string, operationId: string, expiresAt: string) {
  const admin = await authorizeAdmin(token);
  if (!operationId.trim() || !Number.isFinite(Date.parse(expiresAt))) throw new Error('Reservation key and expiry required.');
  return admin.rpc<null>('reserve_order', { p_order: orderId(order), p_key: operationId, p_expires: new Date(expiresAt).toISOString() });
}

export async function finishReservation(token: string, order: string, consume: boolean) {
  const admin = await authorizeAdmin(token);
  return admin.rpc<null>('finish_reservation', { p_order: orderId(order), p_consume: consume });
}
