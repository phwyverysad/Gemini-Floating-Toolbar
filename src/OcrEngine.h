#pragma once

#include <QString>
#include <QImage>
#include <QObject>
#include <QStringList>

class TextScanner : public QObject {
    Q_OBJECT
public:
    static TextScanner& instance();

    // Performs OCR on a QImage synchronously
    QString recognizeImage(const QImage& image, const QString& preferredLang = "auto");

    // Check if OCR is available on this system
    bool isAvailable() const;

    // Get list of supported/installed OCR languages
    QStringList getAvailableLanguages() const;

private:
    TextScanner();
    ~TextScanner() override = default;

    QString recognizeWithWindowsMediaOcr(const QImage& image, const QString& lang);
    QString recognizeWithTesseract(const QImage& image, const QString& lang);
    QString findTesseractPath() const;

    bool m_winMediaOcrAvailable = false;
};

