import React, { useState, useCallback } from "react";
import "./Notification.css";
import { NotificationContext } from "./context";

// Notification Provider Component
export const NotificationProvider = ({ children }) => {
  const [notifications, setNotifications] = useState([]);

  const addNotification = useCallback((notification) => {
    const id = Date.now() + Math.random();
    const newNotification = {
      id,
      type: "info", // default type
      duration: 5000, // default 5 seconds
      ...notification,
    };

    setNotifications((prev) => [...prev, newNotification]);

    // Auto remove notification after duration
    if (newNotification.duration > 0) {
      setTimeout(() => {
        setNotifications((prev) => prev.filter((n) => n.id !== id));
      }, newNotification.duration);
    }

    return id;
  }, []);

  const removeNotification = useCallback((id) => {
    setNotifications((prev) =>
      prev.filter((notification) => notification.id !== id)
    );
  }, []);

  const clearAllNotifications = useCallback(() => {
    setNotifications([]);
  }, []);

  // Convenience methods for different notification types
  const showSuccess = useCallback(
    (message, options = {}) => {
      return addNotification({ type: "success", message, ...options });
    },
    [addNotification]
  );

  const showError = useCallback(
    (message, options = {}) => {
      return addNotification({
        type: "error",
        message,
        duration: 7000,
        ...options,
      });
    },
    [addNotification]
  );

  const showWarning = useCallback(
    (message, options = {}) => {
      return addNotification({ type: "warning", message, ...options });
    },
    [addNotification]
  );

  const showInfo = useCallback(
    (message, options = {}) => {
      return addNotification({ type: "info", message, ...options });
    },
    [addNotification]
  );

  const value = {
    notifications,
    addNotification,
    removeNotification,
    clearAllNotifications,
    showSuccess,
    showError,
    showWarning,
    showInfo,
  };

  return (
    <NotificationContext.Provider value={value}>
      {children}
      <NotificationContainer />
    </NotificationContext.Provider>
  );
};


// Simple Notification Component
const Notification = ({ notification, onRemove }) => {
  const { id, type, message, title } = notification;

  const handleRemove = () => {
    onRemove(id);
  };

  return (
    <div className={`notification notification-${type}`} onClick={handleRemove}>
      <div className="notification-content">
        {title && <div className="notification-title">{title}</div>}
        <div className="notification-message">{message}</div>
      </div>
      <button className="notification-close" onClick={handleRemove}>
        ×
      </button>
    </div>
  );
};

// Notification Container Component
const NotificationContainer = () => {
  const { notifications, removeNotification } = React.useContext(NotificationContext);

  return (
    <div className="notification-container">
      {notifications.map((notification) => (
        <Notification
          key={notification.id}
          notification={notification}
          onRemove={removeNotification}
        />
      ))}
    </div>
  );
};

export default Notification;
