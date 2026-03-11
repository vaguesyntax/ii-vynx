import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects

Canvas { // Visualizer
    id: root
    property list<var> points: []
    property list<var> smoothPoints: [] 
    property var roundedPolygon: null
    property real maxVisualizerValue: 800
    property int smoothing: 2
    property bool live: true
    property color color: Appearance.m3colors.m3primary

    property real waveOpacity: 0.15
    property real waveBlur: 1
    property int contourSamplesPerCubic: 12

    onPointsChanged: () => {
        root.requestPaint()
    }
    onRoundedPolygonChanged: root.requestPaint()
    onWidthChanged: root.requestPaint()
    onHeightChanged: root.requestPaint()

    anchors.fill: parent

    function mapPolygonPoint(point, size, xOffset, yOffset) {
        return {
            x: point.x * size + xOffset,
            y: point.y * size + yOffset
        };
    }

    function getShapeContour(size, xOffset, yOffset) {
        if (!root.roundedPolygon?.cubics?.length) return [];

        const contour = [];
        for (const cubic of root.roundedPolygon.cubics) {
            for (let step = 0; step < root.contourSamplesPerCubic; ++step) {
                const point = cubic.pointOnCurve(step / root.contourSamplesPerCubic);
                contour.push(root.mapPolygonPoint(point, size, xOffset, yOffset));
            }
        }

        if (contour.length > 0) {
            contour.push(contour[0]);
        }

        return contour;
    }

    function raySegmentIntersection(cx, cy, dx, dy, start, end) {
        const sx = end.x - start.x;
        const sy = end.y - start.y;
        const det = dx * sy - dy * sx;
        if (Math.abs(det) < 0.0001) return null;

        const relX = start.x - cx;
        const relY = start.y - cy;
        const t = (relX * sy - relY * sx) / det;
        const u = (relX * dy - relY * dx) / det;
        if (t < 0 || u < 0 || u > 1) return null;

        return {
            x: cx + dx * t,
            y: cy + dy * t,
            distance: t
        };
    }

    function getBoundaryPoint(angle, contour, cx, cy, fallbackRadius) {
        const dx = Math.cos(angle);
        const dy = Math.sin(angle);
        let farthest = null;

        for (let i = 0; i < contour.length - 1; ++i) {
            const hit = root.raySegmentIntersection(cx, cy, dx, dy, contour[i], contour[i + 1]);
            if (hit && (farthest == null || hit.distance > farthest.distance)) {
                farthest = hit;
            }
        }

        if (farthest) return farthest;

        return {
            x: cx + dx * fallbackRadius,
            y: cy + dy * fallbackRadius,
            distance: fallbackRadius
        };
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var points = root.points;
        var maxVal = root.maxVisualizerValue || 1;
        var w = width;
        var h = height;
        var n = points.length;
        if (n < 3) return;

        var maxRadius = Math.min(w, h) / 2;
        var inwardOffsetFactor = 0.8;
        var size = Math.min(w, h);
        var xOffset = (w - size) / 2;
        var yOffset = (h - size) / 2;
        var contour = root.getShapeContour(size, xOffset, yOffset);
        var mappedCenter = root.roundedPolygon?.center
            ? root.mapPolygonPoint(root.roundedPolygon.center, size, xOffset, yOffset)
            : null;
        var cx = mappedCenter ? mappedCenter.x : w / 2;
        var cy = mappedCenter ? mappedCenter.y : h / 2;

        var smoothWindow = root.smoothing; 
        root.smoothPoints = [];
        for (var i = 0; i < n; ++i) {
            var sum = 0, count = 0;
            for (var j = -smoothWindow; j <= smoothWindow; ++j) {
                var idx = Math.max(0, Math.min(n - 1, i + j));
                sum += points[idx];
                count++;
            }
            root.smoothPoints.push(sum / count);
        }
        if (!root.live) root.smoothPoints.fill(0); 
        
        var plotPoints = root.smoothPoints.slice();
        plotPoints.push(root.smoothPoints[0]);
        var visualN = plotPoints.length;
        var boundaryPoints = [];

        for (var i = 0; i < visualN; ++i) {
            var boundaryAngle = (i / (visualN - 1)) * Math.PI * 2 - Math.PI / 2;
            boundaryPoints.push(root.getBoundaryPoint(boundaryAngle, contour, cx, cy, maxRadius));
        }

        ctx.beginPath();

        for (var i = visualN - 1; i >= 0; --i) {
            var normalized = plotPoints[i] / maxVal;
            var angle = (i / (visualN - 1)) * Math.PI * 2 - Math.PI / 2; 
            var boundaryPoint = boundaryPoints[i];
            var minDistance = boundaryPoint.distance * (1 - inwardOffsetFactor);
            var currentDistance = boundaryPoint.distance - (normalized * boundaryPoint.distance * inwardOffsetFactor);
            if (currentDistance < minDistance) {
                currentDistance = minDistance;
            }

            var x = cx + Math.cos(angle) * currentDistance;
            var y = cy + Math.sin(angle) * currentDistance;
            
            if (i === visualN - 1)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }

        for (var i = 0; i < visualN; ++i) {
             ctx.lineTo(boundaryPoints[i].x, boundaryPoints[i].y);
        }

        ctx.closePath(); 
        ctx.fillStyle = Qt.rgba(
            root.color.r,
            root.color.g,
            root.color.b,
            root.waveOpacity
        );
        ctx.fill();
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        source: root
        saturation: 1.0
        blurEnabled: true
        blurMax: 7
        blur: root.waveBlur
    }
}
