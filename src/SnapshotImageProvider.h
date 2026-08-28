#pragma once

#include <QQuickImageProvider>
#include <QPixmap>
#include <QMutex>
#include <QMutexLocker>

class SnapshotImageProvider : public QQuickImageProvider {
public:
    SnapshotImageProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    static SnapshotImageProvider* instance() {
        static SnapshotImageProvider* s_inst = new SnapshotImageProvider();
        return s_inst;
    }

    void setSnapshot(const QPixmap& pixmap) {
        QMutexLocker locker(&m_mutex);
        m_snapshot = pixmap;
    }

    QPixmap getSnapshot() {
        QMutexLocker locker(&m_mutex);
        return m_snapshot;
    }

    QPixmap requestPixmap(const QString& id, QSize* size, const QSize& requestedSize) override {
        Q_UNUSED(id);
        QMutexLocker locker(&m_mutex);
        if (size) {
            *size = m_snapshot.size();
        }
        if (requestedSize.width() > 0 && requestedSize.height() > 0) {
            return m_snapshot.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }
        return m_snapshot;
    }

private:
    QPixmap m_snapshot;
    QMutex m_mutex;
};
