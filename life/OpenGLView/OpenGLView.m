//
//  OpenGLView.m
//  life
//
//  Created by Dmitrii Platov on 10/15/15.
//  Copyright © 2015 dplatov. All rights reserved.
//

#import "OpenGLView.h"
#import <GLKit/GLKit.h>

#define FIELD_HEIGHT 10
#define FIELD_WIDTH 10

//const GLuint field[FIELD_HEIGHT*FIELD_WIDTH];

typedef struct {
    GLfloat position[3];
    GLfloat color[4];
} GLVertex;


typedef struct{
    GLVertex vertices[2];
    GLuint vertextBuffer;
} GLLine;


@interface OpenGLView()
{
//buffers
    GLuint colorRenderBuffer;
    GLuint depthStencilBuffer;
    GLuint linesIndexBuffer;
    GLuint linesIndices[2];
    
    
    GLuint* cellsIndices;
    GLuint cellsVertextBuffer;
    GLuint cellsIndexBuffer;
//shaders
    GLuint lineProgramHandle;
    GLuint linePositionSlot;
    GLuint lineColorSlot;
    
    GLuint cellProgramHandle;
    GLuint cellPositionSlot;
    GLuint cellColorSlot;
    GLuint cellSizeSlot;

}
//data
@property (nonatomic ,readonly) GLuint *field;

@property GLVertex* cells;

@property (nonatomic) GLLine* lines;

@property (readwrite) NSInteger cellCount;//to readwrite

//visualisation
@property (nonatomic, readonly) CAEAGLLayer* eaglLayer;

@property (nonatomic) CADisplayLink* displayLink;

@property (nonatomic) EAGLContext* context;

@property NSTimer* generationTimer;

//touch
@property NSUInteger currentCellIndex;
@end

@implementation OpenGLView

@synthesize field=_field, lines=_lines;
#pragma mark opengl support
+ (Class)layerClass {
    return [CAEAGLLayer class];
}


#pragma mark lifecycle
- (void)dealloc{
    [self.displayLink invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

//    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    //    self.displayLink = nil;
    //    GLuint tId = _gridTexture.textureID;
    //    glDeleteTextures(1, &tId);
    //    glDeleteBuffers(1, &_colorRenderBuffer);
    //    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appDidEnterBackground:(NSNotification*)note{
    
}

- (void)appWillEnterForeground:(NSNotification*)note{
    //    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    //    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    if(self = [super initWithCoder:aDecoder]){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        [self setupLayer];
//        self.context;
//        [self setupDepthBuffer];
        [self setupRenderBuffer];
        [self setupFrameBuffer];
        [self compileShaders];
        [self setupVBOs];
//        self.lines;
        [self setupFirstGeneration];

        [self setupDisplayLink];
        

//        self.generationTimer = [NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(nextGeneration) userInfo:nil repeats:YES];
    }
    
    return self;
}

#pragma mark touches
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch* touch = [touches anyObject];
    if(!touch){
        self.currentCellIndex = NSUIntegerMax;
    }
    
    NSUInteger index = [self indexWithTouchPoint:[touch locationInView:self]];
    
    [self commonTouchHandlerWithIndex:index];
}


- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch* touch = [touches anyObject];
    if(!touch){
        self.currentCellIndex = NSUIntegerMax;
    }
    
    NSUInteger index = [self indexWithTouchPoint:[touch locationInView:self]];
    
    [self commonTouchHandlerWithIndex:index];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    self.currentCellIndex = NSUIntegerMax;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    self.currentCellIndex = NSUIntegerMax;
}

- (void)commonTouchHandlerWithIndex:(NSUInteger)index{
    if(index != self.currentCellIndex){
        self.currentCellIndex = index;
        if(index == NSUIntegerMax){
            return;
        }
        
        if(self.field[index]){
            self.field[index] = 0;
            --self.cellCount;
        }else{
            self.field[index] = 1;
            ++self.cellCount;
        }
        
        [self setupBufferDataForGeneration];
    }
}
#pragma mark setup
- (void)setupLayer{
    self.eaglLayer.opaque = YES;
}

- (void)setupRenderBuffer {
    EAGLContext* ctx = self.context;
    if(!ctx){
        exit(1);
    }
    
    glGenRenderbuffers(1, &colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderBuffer);
//    glGenRenderbuffers(1, &depthStencilBuffer);
//    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderBuffer);
    [ctx renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
}

- (void)setupFrameBuffer {
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderBuffer);
}

- (void)setupVBOs {
    
    linesIndices[0] = 0;
    linesIndices[1] = 1;
    
    glGenBuffers(1, &linesIndexBuffer);
    
    glGenBuffers(1, &cellsIndexBuffer);
    
    glGenBuffers(1, &cellsVertextBuffer);

}

- (void)compileShaders {

    GLuint vertexShader = [self compileShader:@"LineVertex" withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"LineFragment" withType:GL_FRAGMENT_SHADER];
    
    lineProgramHandle = glCreateProgram();
    glAttachShader(lineProgramHandle, vertexShader);
    glAttachShader(lineProgramHandle, fragmentShader);
    glLinkProgram(lineProgramHandle);
    
    
    GLint linkSuccess;
    glGetProgramiv(lineProgramHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(lineProgramHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(lineProgramHandle);
    linePositionSlot = glGetAttribLocation(lineProgramHandle, "Position");
    lineColorSlot = glGetAttribLocation(lineProgramHandle, "SourceColor");
    glEnableVertexAttribArray(linePositionSlot);
    glEnableVertexAttribArray(lineColorSlot);
    

    
    vertexShader = [self compileShader:@"CellVertex" withType:GL_VERTEX_SHADER];
    fragmentShader = [self compileShader:@"CellFragment" withType:GL_FRAGMENT_SHADER];
    
    cellProgramHandle = glCreateProgram();
    glAttachShader(cellProgramHandle, vertexShader);
    glAttachShader(cellProgramHandle, fragmentShader);
    glLinkProgram(cellProgramHandle);
    
    
    // 3
    glGetProgramiv(cellProgramHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(cellProgramHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(cellProgramHandle);
    cellPositionSlot = glGetAttribLocation(cellProgramHandle, "Position");
    cellColorSlot = glGetAttribLocation(cellProgramHandle, "SourceColor");
    cellSizeSlot = glGetUniformLocation(cellProgramHandle, "PointSize");
    glEnableVertexAttribArray(cellPositionSlot);
    glEnableVertexAttribArray(cellColorSlot);
}

- (void)setupDisplayLink{
    if(_displayLink){
        return;
    }
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

#pragma mark getter
- (CAEAGLLayer*)eaglLayer{
    return (CAEAGLLayer*)self.layer;
}

- (EAGLContext*)context{
    if(_context){
        return _context;
    }
    
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
    
    
    
    return _context;
}

- (CADisplayLink*)displayLink{
    if(_displayLink){
        return _displayLink;
    }
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    return _displayLink;
}

- (GLuint*)field{
    if(_field){
        return _field;
    }
    
    _field = calloc(FIELD_HEIGHT*FIELD_WIDTH, sizeof(GLuint));
    
    return _field;
}

- (GLLine*)lines{
    if(_lines){
        return _lines;
    }
    
    _lines = malloc(sizeof(GLLine)*FIELD_WIDTH*FIELD_HEIGHT);
    
    GLfloat horisontalSpace = 2.0/(FIELD_WIDTH + 1);
    GLfloat verticalSpace = 2.0/(FIELD_HEIGHT + 1);

    
    for(NSUInteger i = 0; i<FIELD_WIDTH; ++i){
        //start
        _lines[i].vertices[0].position[0] = (i + 1)*horisontalSpace - 1.0;
        _lines[i].vertices[0].position[1] = - 1.0;
        _lines[i].vertices[0].position[2] = 0.0;
        //end
        _lines[i].vertices[1].position[0] = _lines[i].vertices[0].position[0];
        _lines[i].vertices[1].position[1] = 1.0;
        _lines[i].vertices[1].position[2] = 0.0;
    }
    
    for(NSUInteger i = FIELD_WIDTH; i<FIELD_HEIGHT+FIELD_WIDTH; ++i){
        NSUInteger leftIndex = i - FIELD_WIDTH;
        //start
        _lines[i].vertices[0].position[0] = - 1.0;
        _lines[i].vertices[0].position[1] = (leftIndex + 1)*verticalSpace - 1.0;
        _lines[i].vertices[0].position[2] = 0.0;
        //end
        _lines[i].vertices[1].position[0] = 1.0;
        _lines[i].vertices[1].position[1] = _lines[i].vertices[0].position[1];
        _lines[i].vertices[1].position[2] = 0.0;
    }
    
    //color
    for(NSUInteger i = 0; i<FIELD_HEIGHT+FIELD_WIDTH; ++i){
        
        _lines[i].vertices[0].color[0] = 1.0;
        _lines[i].vertices[0].color[1] = 1.0;
        _lines[i].vertices[0].color[2] = 0.0;
        _lines[i].vertices[0].color[3] = 1.0;
        
        _lines[i].vertices[1].color[0] = 1.0;
        _lines[i].vertices[1].color[1] = 1.0;
        _lines[i].vertices[1].color[2] = 0.0;
        _lines[i].vertices[1].color[3] = 1.0;

        
        glGenBuffers(1, &_lines[i].vertextBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _lines[i].vertextBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(_lines), _lines, GL_STATIC_DRAW);
    }
    
    return _lines;
}


#pragma mark render
- (void)render:(CADisplayLink*)sender{
//    NSLog(@"timestamp - %f", sender.timestamp);
    glClearColor(139./255., .0, 1, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);


    glUseProgram(lineProgramHandle);
    

    for(NSUInteger i = 0; i<FIELD_HEIGHT + FIELD_WIDTH; ++i){
        
        GLLine line = self.lines[i];
        glBindBuffer(GL_ARRAY_BUFFER, line.vertextBuffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, linesIndexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(self.lines[i].vertices), self.lines[i].vertices, GL_STATIC_DRAW);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(linesIndices), linesIndices, GL_STATIC_DRAW);
        

        glVertexAttribPointer(linePositionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), 0);
        glVertexAttribPointer(lineColorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(GLVertex), (GLvoid*)(sizeof(float) * 3));
        glEnableVertexAttribArray(linePositionSlot);
        glEnableVertexAttribArray(lineColorSlot);
        
        glDrawElements(GL_LINES, sizeof(linesIndices)/sizeof(*linesIndices), GL_UNSIGNED_INT, 0);
    }
    
    
    glUseProgram(cellProgramHandle);
    
    
    glBindBuffer(GL_ARRAY_BUFFER, cellsVertextBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cellsIndexBuffer);
    
    
    glVertexAttribPointer(cellPositionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), 0);
    glVertexAttribPointer(cellColorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(GLVertex), (GLvoid*)(sizeof(float) * 3));
    glUniform1f(cellSizeSlot, 6.5);
    glEnableVertexAttribArray(cellPositionSlot);
    glEnableVertexAttribArray(cellColorSlot);
    
    glDrawElements(GL_POINTS, (GLsizei)self.cellCount, GL_UNSIGNED_INT, 0);

    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark life
- (void)setupFirstGeneration{
    self.currentCellIndex = NSUIntegerMax;
    NSArray* cells = @[@70, @71, @72, @82, @91];//glider
    [cells enumerateObjectsUsingBlock:^(NSNumber*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        self.field[[obj integerValue]] = 1;
    }];
    
    self.cellCount = [cells count];
    [self setupBufferDataForGeneration];
}

- (void)clearField{
    if(_field){
        free(_field);
        _field = NULL;
    }
    
    self.cellCount = 0;
    [self setupBufferDataForGeneration];
}

/**
 @return if timer stops return NO, if run return YES
 */
- (BOOL)runTimer{
    if(self.generationTimer){
        [self.generationTimer invalidate];
        self.generationTimer = nil;
        return NO;
    }else{
        
        self.generationTimer = [NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(nextGeneration) userInfo:nil repeats:YES];
        return YES;
    }
}

- (void)nextGeneration{
    NSUInteger cellAroundCounters[FIELD_HEIGHT*FIELD_WIDTH];
    for(NSUInteger i = 0; i<FIELD_HEIGHT*FIELD_WIDTH;++i){
        NSUInteger column = i - FIELD_WIDTH*(i/FIELD_WIDTH);
        NSUInteger row = i/FIELD_WIDTH;
        NSUInteger cellAroundCounter = 0;
        
        //bottom
        if(row>0){
            if(self.field[i - FIELD_WIDTH]){
                ++cellAroundCounter;
            }
            if(column>0){
                if(self.field[i - FIELD_WIDTH - 1]){
                    ++cellAroundCounter;
                }
            }
            if(column<FIELD_WIDTH - 1){
                if(self.field[i - FIELD_WIDTH + 1]){
                    ++cellAroundCounter;
                }
            }
        }
        //top
        if(row<FIELD_HEIGHT - 1){
            if(self.field[i + FIELD_WIDTH]){
                ++cellAroundCounter;
            }
            if(column>0){
                if(self.field[i + FIELD_WIDTH - 1]){
                    ++cellAroundCounter;
                }
            }
            if(column<FIELD_WIDTH - 1){
                if(self.field[i + FIELD_WIDTH + 1]){
                    ++cellAroundCounter;
                }
            }
        }
        //left
        if(column>0){
            if(self.field[i - 1]){
                ++cellAroundCounter;
            }
        }
        //right
        if(column<FIELD_WIDTH - 1){
            if(self.field[i + 1]){
                ++cellAroundCounter;
            }
        }

        cellAroundCounters[i] = cellAroundCounter;
    }
    
    for(NSUInteger i = 0; i<FIELD_HEIGHT*FIELD_WIDTH;++i){
        NSUInteger cellAroundCounter = cellAroundCounters[i];
        
        if(self.field[i]){
            if(cellAroundCounter<2 || cellAroundCounter>3){//dead
                self.field[i] = 0;
                --self.cellCount;
            }
        }else{
            if(cellAroundCounter == 3){//born
                self.field[i] = 1;
                ++self.cellCount;
            }
        }
    }
    

    [self setupBufferDataForGeneration];
}

- (void)setupBufferDataForGeneration{
    
    if(self.cells){
        free(self.cells);
        self.cells = NULL;
    }
    
    if(!self.cellCount){
        return;
    }
    
    self.cells = calloc(self.cellCount, sizeof(GLVertex));
    GLfloat horisontalSpace = 2.0/(FIELD_WIDTH + 1);
    GLfloat verticalSpace = 2.0/(FIELD_HEIGHT + 1);
    
    NSUInteger cellIndex = 0;
    for(NSUInteger i = 0; i<FIELD_HEIGHT*FIELD_WIDTH;++i){
        if(!self.field[i]){
            continue;
        }
        
        NSUInteger column = i - FIELD_WIDTH*(i/FIELD_WIDTH);
        NSUInteger row = i/FIELD_WIDTH;
        
        GLfloat left = (column + 1)*horisontalSpace - 1.0;
        GLfloat top = (row + 1)*verticalSpace - 1.0;
        
        self.cells[cellIndex++] = (GLVertex){{left, top, 0.0},{255./255., 255./255., 0./255., 1.0}};
    }
    
    
    glBindBuffer(GL_ARRAY_BUFFER, cellsVertextBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLVertex)*self.cellCount, self.cells, GL_STATIC_DRAW);
    
    if(cellsIndices){
        free(cellsIndices);
        cellsIndices = NULL;
    }
    cellsIndices = malloc(sizeof(GLuint)*self.cellCount);
    for(GLuint i = 0; i<self.cellCount; ++i){
        cellsIndices[i] = i;
    }
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cellsIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(*cellsIndices)*self.cellCount, cellsIndices, GL_STATIC_DRAW);
}

#pragma mark helper
- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType {
    
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName
                                                           ofType:@"glsl"];
    NSError* error;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    GLuint shaderHandle = glCreateShader(shaderType);
    
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    glCompileShader(shaderHandle);
    
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
}

- (NSUInteger)indexWithTouchPoint:(CGPoint)point{
    NSInteger row = FIELD_HEIGHT - (NSInteger)point.y/(self.frame.size.height/FIELD_HEIGHT);
    NSInteger column = (NSInteger)point.x/(self.frame.size.width/FIELD_WIDTH);
    
    if(row<0 || column<0){
        return NSUIntegerMax;
    }
    
    return column+(row*FIELD_WIDTH);
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
