#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QImage>
#include <QPixmap>

class OcrEngine : public QObject {
    Q_OBJECT
public:
    static OcrEngine* instance();

    // Recognize text from image (default: "tha+eng")
    QString recognizeText(const QImage& image, const QString& languages = "tha+eng");
    QString recognizeText(const QPixmap& pixmap, const QString& languages = "tha+eng");

    // Availability and language inspection
    bool isAvailable() const;
    QStringList availableLanguages() const;
    QString tessdataPath() const { return m_tessdataPath; }

private:
    explicit OcrEngine(QObject* parent = nullptr);
    ~OcrEngine();

    QString findTessdataPath() const;

    QString m_tessdataPath;
};
