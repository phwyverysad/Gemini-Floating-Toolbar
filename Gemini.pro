QT += core gui qml quick widgets
CONFIG += c++20 release utf8_source
CONFIG -= embed_manifest_exe

TARGET = Gemini
TEMPLATE = app

DESTDIR = $$PWD
OBJECTS_DIR = $$PWD/obj
MOC_DIR = $$PWD/moc
RCC_DIR = $$PWD/rcc
UI_DIR = $$PWD/uic

DEFINES += UNICODE _UNICODE NDEBUG

INCLUDEPATH += \
    $$PWD/packages/WebView2/build/native/include \
    $$PWD/resources \
    $$PWD/src

LIBS += \
    -L$$PWD/packages/WebView2/build/native/x64 \
    -lWebView2LoaderStatic \
    -lshell32 -luser32 -lgdi32 -ladvapi32 -lole32 -loleaut32 -lshlwapi -ldwmapi -lwindowsapp

HEADERS += \
    src/AppManager.h \
    src/WebViewWindow.h \
    src/SnapshotImageProvider.h \
    src/OcrEngine.h \
    resources/resource.h

SOURCES += \
    src/main.cpp \
    src/AppManager.cpp \
    src/WebViewWindow.cpp \
    src/OcrEngine.cpp

RESOURCES += \
    resources/qml.qrc

RC_FILE = resources/app.rc

QMAKE_CXXFLAGS += /guard:cf /utf-8
QMAKE_LFLAGS += /SUBSYSTEM:WINDOWS /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA /OPT:REF /OPT:ICF /guard:cf
