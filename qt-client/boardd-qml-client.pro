QT += quick qml network

CONFIG += c++11
CONFIG -= app_bundle

TEMPLATE = app
TARGET = boardd-qml-client

SOURCES += \
    main.cpp \
    BoardClient.cpp

HEADERS += \
    BoardClient.h
