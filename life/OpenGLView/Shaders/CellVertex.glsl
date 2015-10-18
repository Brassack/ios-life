uniform float PointSize;
attribute vec4 Position;
attribute vec4 SourceColor;


varying vec4 DestinationColor;

void main() {
    DestinationColor = SourceColor;
    gl_Position = Position;
    gl_PointSize = PointSize;
}