import { ReactNode } from 'react';

import { cx } from './cx';
import styles from './ui.module.css';

export type AlertVariant = 'info' | 'success' | 'warning' | 'danger';

const variantClass: Record<AlertVariant, string> = {
  info: styles.alertInfo,
  success: styles.alertSuccess,
  warning: styles.alertWarning,
  danger: styles.alertDanger,
};

export function Alert({
  variant = 'info',
  live = true,
  children,
}: {
  variant?: AlertVariant;
  /**
   * `false`: no live role. For a text a parent's own status region already
   * announces, so screen readers hear it once, not twice.
   */
  live?: boolean;
  children: ReactNode;
}) {
  return (
    <div
      className={cx(styles.alert, variantClass[variant])}
      // urgent variants interrupt the SR; informational ones are polite.
      role={
        !live ? undefined : variant === 'danger' || variant === 'warning' ? 'alert' : 'status'
      }
    >
      {children}
    </div>
  );
}
