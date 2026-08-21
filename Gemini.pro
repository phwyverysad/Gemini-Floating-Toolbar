QT += core gui qml quick widgets
CONFIG += c++20 release utf8_source
CONFIG -= embed_manifest_exe

TARGET = Gemini
TEMPLATE = app

DEFINES += UNICODE _UNICODE NDEBUG

INCLUDEPATH += \
    $$PWD/packages/WebView2/build/native/include \
    $$PWD/resources \
    $$PWD/src

LIBS += \
    -L$$PWD/packages/WebView2/build/native/x64 \
    -lWebView2LoaderStatic \
    -lshell32 -luser32 -lgdi32 -ladvapi32 -lole32 -lshlwapi

HEADERS += \
    src/AppManager.h \
    src/WebViewWindow.h \
    resources/resource.h

SOURCES += \
    src/main.cpp \
    src/AppManager.cpp \
    src/WebViewWindow.cpp

RESOURCES += \
    qml.qrc

RC_FILE = resources/app.rc

QMAKE_LFLAGS += /SUBSYSTEM:WINDOWS /DEBUG /OPT:REF /OPT:ICF /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA
