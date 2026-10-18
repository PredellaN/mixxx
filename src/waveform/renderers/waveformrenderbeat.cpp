#include "waveform/renderers/waveformrenderbeat.h"

#include <QPainter>
#include <array>

#include "track/track.h"
#include "util/painterscope.h"
#include "waveform/renderers/waveformwidgetrenderer.h"
#include "widget/wskincolor.h"

class QPaintEvent;

WaveformRenderBeat::WaveformRenderBeat(WaveformWidgetRenderer* waveformWidgetRenderer)
        : WaveformRendererAbstract(waveformWidgetRenderer) {
    for (auto& beats : m_beats) {
        beats.resize(128);
    }
}

WaveformRenderBeat::~WaveformRenderBeat() {
}

void WaveformRenderBeat::setup(const QDomNode& node, const SkinContext& context) {
    m_beatColor = QColor(context.selectString(node, "BeatColor"));
    m_beatColor = WSkinColor::getCorrectColor(m_beatColor).toRgb();
}

void WaveformRenderBeat::draw(QPainter* painter, QPaintEvent* /*event*/) {
    TrackPointer pTrackInfo = m_waveformRenderer->getTrackInfo();

    if (!pTrackInfo) {
        return;
    }

    mixxx::BeatsPointer trackBeats = pTrackInfo->getBeats();
    if (!trackBeats) {
        return;
    }

    int alpha = m_waveformRenderer->getBeatGridAlpha();
    if (alpha == 0) {
        return;
    }

    const double trackSamples = m_waveformRenderer->getTrackSamples();
    if (trackSamples <= 0) {
        return;
    }

    const float devicePixelRatio = m_waveformRenderer->getDevicePixelRatio();

    const double firstDisplayedPosition =
            m_waveformRenderer->getFirstDisplayedPosition();
    const double lastDisplayedPosition =
            m_waveformRenderer->getLastDisplayedPosition();

    // qDebug() << "trackSamples" << trackSamples
    //          << "firstDisplayedPosition" << firstDisplayedPosition
    //          << "lastDisplayedPosition" << lastDisplayedPosition;

    const auto startPosition = mixxx::audio::FramePos::fromEngineSamplePos(
            firstDisplayedPosition * trackSamples);
    const auto endPosition = mixxx::audio::FramePos::fromEngineSamplePos(
            lastDisplayedPosition * trackSamples);
    auto it = trackBeats->iteratorFrom(startPosition);

    // if no beat do not waste time saving/restoring painter
    if (it == trackBeats->cend() || *it > endPosition) {
        return;
    }

    QColor color1Beat = m_beatColor;
    QColor color8Beats(255, 255, 255);
    color8Beats.setAlphaF(m_beatColor.alphaF());
    QColor color4Beats(
            (color1Beat.red() + color8Beats.red()) / 2,
            (color1Beat.green() + color8Beats.green()) / 2,
            (color1Beat.blue() + color8Beats.blue()) / 2);
    color4Beats.setAlphaF((color1Beat.alphaF() + color8Beats.alphaF()) / 2.0f);
    QColor color16Beats(255, 0, 0);
    color16Beats.setAlphaF(color8Beats.alphaF());

#ifdef MIXXX_USE_QOPENGL
    // Using alpha transparency with drawLines causes a graphical issue when
    // drawing with QPainter on the QOpenGLWindow: instead of individual lines
    // a large rectangle encompassing all beatlines is drawn.
    color1Beat.setAlphaF(1.f);
    color4Beats.setAlphaF(1.f);
    color8Beats.setAlphaF(1.f);
    color16Beats.setAlphaF(1.f);
#else
    color1Beat.setAlphaF(alpha / 100.0);
    color4Beats.setAlphaF(alpha / 100.0);
    color8Beats.setAlphaF(alpha / 100.0);
    color16Beats.setAlphaF(alpha / 100.0);
#endif

    const std::array<QColor, 4> beatColors = {
            color1Beat,
            color4Beats,
            color8Beats,
            color16Beats,
    };
    std::array<int, 4> beatCounts = {0, 0, 0, 0};

    PainterScope PainterScope(painter);

    painter->setRenderHint(QPainter::Antialiasing);

    const Qt::Orientation orientation = m_waveformRenderer->getOrientation();
    const float rendererWidth = m_waveformRenderer->getWidth();
    const float rendererHeight = m_waveformRenderer->getHeight();

    const auto firstMarkerIt = trackBeats->cfirstmarker();
    int beatIndex = static_cast<int>(it - firstMarkerIt);

    for (; it != trackBeats->cend() && *it <= endPosition; ++it, ++beatIndex) {
        int mod16 = (beatIndex % 16 + 16) % 16;
        int category = (mod16 == 0)           ? 3
                : (mod16 == 8)                ? 2
                : (mod16 == 4 || mod16 == 12) ? 1
                                              : 0;

        double beatPosition = it->toEngineSamplePos();
        double xBeatPoint =
                m_waveformRenderer->transformSamplePositionInRendererWorld(beatPosition);

        xBeatPoint = qRound(xBeatPoint * devicePixelRatio) / devicePixelRatio;

        // If we don't have enough space, double the size.
        if (beatCounts[category] >= m_beats[category].size()) {
            m_beats[category].resize(m_beats[category].size() * 2);
        }

        if (orientation == Qt::Horizontal) {
            m_beats[category][beatCounts[category]++].setLine(
                    xBeatPoint, 0.0f, xBeatPoint, rendererHeight);
        } else {
            m_beats[category][beatCounts[category]++].setLine(
                    0.0f, xBeatPoint, rendererWidth, xBeatPoint);
        }
    }

    for (size_t i = 0; i < 4; ++i) {
        if (beatCounts[i] > 0) {
            QPen beatPen(beatColors[i]);
            beatPen.setWidthF(std::max(1.0, scaleFactor()));
            painter->setPen(beatPen);
            painter->drawLines(m_beats[i].constData(), beatCounts[i]);
        }
    }
}
