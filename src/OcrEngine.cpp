#include "OcrEngine.h"
#include <tesseract/baseapi.h>
#include <leptonica/allheaders.h>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QBuffer>
#include <QDebug>
#include <memory>

OcrEngine* OcrEngine::instance() {
    static OcrEngine s_instance;
    return &s_instance;
}

OcrEngine::OcrEngine(QObject* parent)
    : QObject(parent)
{
    m_tessdataPath = findTessdataPath();
}

OcrEngine::~OcrEngine() {
}

QString OcrEngine::findTessdataPath() const {
    QStringList searchPaths = {
        QCoreApplication::applicationDirPath() + "/tessdata",
        QCoreApplication::applicationDirPath() + "/../tessdata",
        "tessdata",
        "C:/Users/woran/Documents/My_Project/C++/Gemini/tessdata",
        "C:/Users/woran/Documents/antigravity/magical-mendel",
        "C:/Users/woran/Documents/antigravity/sharp-babbage/deps/share/tessdata"
    };

    for (const QString& path : searchPaths) {
        if (QDir(path).exists() && (QFile::exists(path + "/eng.traineddata") || QFile::exists(path + "/tha.traineddata"))) {
            return QDir::toNativeSeparators(QDir(path).absolutePath());
        }
    }
    return QString();
}

bool OcrEngine::isAvailable() const {
    return !m_tessdataPath.isEmpty();
}

QStringList OcrEngine::availableLanguages() const {
    QStringList langs;
    if (m_tessdataPath.isEmpty()) return langs;
    QDir dir(m_tessdataPath);
    QStringList files = dir.entryList(QStringList() << "*.traineddata", QDir::Files);
    for (const QString& f : files) {
        QString lang = f.left(f.length() - 12); // remove .traineddata
        if (lang != "osd") {
            langs.append(lang);
        }
    }
    return langs;
}

static Pix* convertQImageToPix(const QImage& srcImage) {
    if (srcImage.isNull()) return nullptr;

    QImage img = srcImage;
    // Scale up tiny text regions (< 60px height) for higher OCR accuracy
    if (img.height() < 60 || img.width() < 60) {
        double scale = std::max(2.0, 120.0 / std::max(1, img.height()));
        scale = std::min(4.0, scale);
        img = img.scaled(img.width() * scale, img.height() * scale, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    QBuffer buffer;
    buffer.open(QIODevice::WriteOnly);
    img.save(&buffer, "BMP");
    const QByteArray& data = buffer.data();

    Pix* pix = pixReadMemBmp(reinterpret_cast<const l_uint8*>(data.constData()), data.size());
    return pix;
}

QString OcrEngine::recognizeText(const QPixmap& pixmap, const QString& languages) {
    if (pixmap.isNull()) return QString();
    return recognizeText(pixmap.toImage(), languages);
}

QString OcrEngine::recognizeText(const QImage& image, const QString& languages) {
    if (image.isNull()) return QString();

    if (m_tessdataPath.isEmpty()) {
        m_tessdataPath = findTessdataPath();
    }
    if (m_tessdataPath.isEmpty()) {
        qWarning() << "[OCR] Tessdata directory not found.";
        return QString();
    }

    QString langToUse = languages.isEmpty() ? "tha+eng" : languages;
    QStringList avail = availableLanguages();
    if (!avail.contains("tha") && langToUse.contains("tha")) {
        langToUse = "eng";
    }

    std::unique_ptr<tesseract::TessBaseAPI> api(new tesseract::TessBaseAPI());
    
    QByteArray tessPathBytes = m_tessdataPath.toUtf8();
    QByteArray langBytes = langToUse.toUtf8();

    if (api->Init(tessPathBytes.constData(), langBytes.constData(), tesseract::OEM_LSTM_ONLY) != 0) {
        if (api->Init(tessPathBytes.constData(), langBytes.constData(), tesseract::OEM_DEFAULT) != 0) {
            if (api->Init(tessPathBytes.constData(), "eng", tesseract::OEM_DEFAULT) != 0) {
                qWarning() << "[OCR] Failed to initialize Tesseract with" << langToUse;
                return QString();
            }
        }
    }

    api->SetPageSegMode(tesseract::PSM_AUTO);

    Pix* pix = convertQImageToPix(image);
    if (!pix) {
        api->End();
        return QString();
    }

    api->SetImage(pix);
    api->Recognize(0);

    char* outText = api->GetUTF8Text();
    QString result;
    if (outText) {
        result = QString::fromUtf8(outText).trimmed();
        delete[] outText;
    }

    pixDestroy(&pix);
    api->End();

    return result;
}
