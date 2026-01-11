cmake_minimum_required(VERSION 3.21)

project(AlphaJuno2Editor VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(FetchContent)

FetchContent_Declare(
  JUCE
  GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
  GIT_TAG 8.0.12
)

FetchContent_MakeAvailable(JUCE)

juce_add_gui_app(AlphaJuno2Editor
  PRODUCT_NAME "Alpha Juno-2 Editor"
  COMPANY_NAME "BlackAlphoa"
)

target_sources(AlphaJuno2Editor
  PRIVATE
    src/Main.cpp
    src/MainComponent.cpp
    src/MainComponent.h
    src/RolandSysex.h
    src/ui/UheTheme.h
    src/ui/UhePanel.h
    src/ui/LCDDisplay.h
    src/ui/UheLookAndFeel.h
)

target_compile_definitions(AlphaJuno2Editor
  PRIVATE
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_MODAL_LOOPS_PERMITTED=1
)

target_link_libraries(AlphaJuno2Editor
  PRIVATE
    juce::juce_audio_devices
    juce::juce_gui_extra
  PUBLIC
    juce::juce_recommended_config_flags
    juce::juce_recommended_lto_flags
    juce::juce_recommended_warning_flags
)

