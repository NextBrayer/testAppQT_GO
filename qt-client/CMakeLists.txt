cmake_minimum_required(VERSION 3.16)

project(boardd_qml_client VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt5 5.12 REQUIRED COMPONENTS Quick Qml Network)

qt5_add_resources(QML_RESOURCES resources.qrc)

add_executable(boardd-qml-client
    main.cpp
    BoardClient.cpp
    BoardClient.h
    ${QML_RESOURCES}
)

target_link_libraries(boardd-qml-client PRIVATE Qt5::Quick Qt5::Qml Qt5::Network)

install(TARGETS boardd-qml-client RUNTIME DESTINATION bin)
