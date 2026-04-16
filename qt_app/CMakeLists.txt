cmake_minimum_required(VERSION 3.20)
project(GuitarProcessorGUI VERSION 1.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt6 path
set(CMAKE_PREFIX_PATH "C:/Qt/6.7.3/mingw_64")

find_package(Qt6 REQUIRED COMPONENTS Widgets SerialPort PrintSupport)

# Sources
set(SOURCES
    main.cpp
    qcustomplot.cpp
    src/MainWindow.cpp
    src/SerialManager.cpp
    src/AudioDataModel.cpp
    src/WaveformWidget.cpp
    src/SpectrumWidget.cpp
    src/PedalBoard.cpp
    src/VuMeterWidget.cpp
    src/KnobWidget.cpp

)

set(HEADERS
    qcustomplot.h
    src/MainWindow.h
    src/SerialManager.h
    src/AudioDataModel.h
    src/WaveformWidget.h
    src/SpectrumWidget.h
    src/PedalBoard.h
    src/VuMeterWidget.h
    src/KnobWidget.h
    src/SimpleFFT.h
)

add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS})

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Widgets
    Qt6::SerialPort
    Qt6::PrintSupport
)

# Windows-specific: suppress console in release
if(WIN32)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        WIN32_EXECUTABLE $<$<CONFIG:Release>:TRUE>
    )
endif()
