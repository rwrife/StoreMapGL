#import "StoreMapGLKitViewController.h"

typedef struct {
    float Position[3];
    float Color[4];
    float Texture[2];
    float Normal[3];
} Vertex;

//pan
CGPoint panCoord;
float sX = 0.0f;
float sY = 0.0f;
float tX = 0.0f;
float tY = 0.0f;

//zoom
float pS = 1.0f;
float tS = 1.0f;

//go 3D
CGPoint twoPanCoord;
float tsY = 0.0f;
float tsX = 0.0f;
float ttY = 0.0f;
float ttX = 0.0f;

int numTouches = 0;

Vertex storeVertices[1500];

GLushort Indices[4000];

@interface StoreMapGLKitViewController () {
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
    GLuint _vertexArray;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

@end

@implementation StoreMapGLKitViewController
@synthesize context = _context;
@synthesize effect = _effect;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) { }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    GLKVector4 bounds = GLKVector4Make(0.0f, 0.0f, 0.0f, 0.0f);
    
    NSDictionary* aisles = [self readStoreCadFile:@"6709.csv" bounds:&bounds];
    [self setStoreVertices:aisles bounds:bounds];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Error");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    [self setup];
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragging:)];
    [panRecognizer setMinimumNumberOfTouches:1];
    [panRecognizer setMaximumNumberOfTouches:2];
    [view addGestureRecognizer:panRecognizer];
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinching:)];
    [view addGestureRecognizer:pinchRecognizer];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [self teardown];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)setup {
    [EAGLContext setCurrentContext:self.context];
    
    glEnable (GL_BLEND);
    glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_FRONT);
    glEnable(GL_DEPTH_TEST);
    
    self.effect = [[GLKBaseEffect alloc] init];
    
    self.effect.colorMaterialEnabled = GL_TRUE;
    
    self.effect.lightingType = GLKLightingTypePerPixel;
    self.effect.light0.enabled = GL_TRUE;
    self.effect.light0.diffuseColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 0.5f);
    self.effect.light0.ambientColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 0.2f);
    self.effect.light0.specularColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 0.4f);

    self.effect.light1.enabled = GL_TRUE;
    self.effect.light1.diffuseColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 0.8f);
    self.effect.light1.specularColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 0.4f);

    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(storeVertices), storeVertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Position));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Color));
    
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Normal));
}

- (void)teardown {
    [EAGLContext setCurrentContext:self.context];
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    self.effect = nil;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glClearColor(0.95, 0.95, 0.95, 1.0);
    
    [self.effect prepareToDraw];
    
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_SHORT, 0);
}

- (void)update {
    
    
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix =  GLKMatrix4MakePerspective(GLKMathDegreesToRadians(35.0f), aspect, 1.0f, 100.0f);
    self.effect.transform.projectionMatrix = projectionMatrix;
        
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(sX, sY, (-3.0f + (pS/2)));
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(tsY*180), 1, 0, 0);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(tsX*180), 0, 0, 1);
    self.effect.transform.modelviewMatrix = modelViewMatrix;
    
    self.effect.light0.position = GLKVector4Make(3.0, 3.0, 10.0, 0.0);
    self.effect.light0.position = GLKVector4Make(-3.0, -3.0, 10.0, 0.0);
}


#pragma mark - Touch controls

-(void)pinching:(UIPinchGestureRecognizer *)gesture
{
    if(gesture.state == UIGestureRecognizerStateBegan) {
        tS = pS;
    } else if(gesture.state == UIGestureRecognizerStateEnded) { }
    
    pS = tS * gesture.scale;
}

-(void)dragging:(UIPanGestureRecognizer *)gesture
{
    int w = self.view.bounds.size.width;
    int h = self.view.bounds.size.height;

    if(gesture.state == UIGestureRecognizerStateBegan && numTouches == 0)
    {
        panCoord = [gesture locationInView:gesture.view];
        numTouches = gesture.numberOfTouches;
    }
    
    if(gesture.state == UIGestureRecognizerStateEnded)
    {
        numTouches = 0;
    }
    
    CGPoint newCoord = [gesture locationInView:gesture.view];
    float dX = newCoord.x-panCoord.x;
    float dY = newCoord.y-panCoord.y;
    
    if(numTouches == 1) {
        if(gesture.state == UIGestureRecognizerStateBegan)
        {
            tX = sX;
            tY = sY;
        }
        
        sX = tX + dX/w;
        sY = tY + (0 - dY/h);
    } else if(numTouches == 2) {
        if(gesture.state == UIGestureRecognizerStateBegan)
        {
            tX = tsX;
            tY = tsY;
        }
        
        tsY = tY + (0 - dY/h);
        tsX = tX + dX/w;
    }
    
}

#pragma mark - Parse store cad file

-(void) setStoreVertices:(NSDictionary*) aisles bounds:(GLKVector4) bounds {
    NSLog(@"aisle count %d", aisles.count);
    for(int k=0;k<[aisles allKeys].count;k++) { //loop each aisle
        NSString *key = [[aisles allKeys] objectAtIndex:k];
        if([key caseInsensitiveCompare:@"FOOTPRINT"] != NSOrderedSame) {
            NSArray* aisle = (NSArray*) [aisles objectForKey:[[aisles allKeys] objectAtIndex:k]];
            
            for(int i=0;i<4;i++) { //loop each point in aisle
                NSArray* point = [aisle objectAtIndex:i];
                
                int w = bounds.z - bounds.x;
                int h = bounds.w - bounds.y;
                
                float x = ([(NSNumber*)[point objectAtIndex:0] floatValue] - (bounds.x + w/2)) / w;
                float y = ([(NSNumber*)[point objectAtIndex:1] floatValue] - (bounds.y + h/2)) / w;
                //float z = [(NSNumber*)[point objectAtIndex:2] floatValue]; //0
                
                int index = k*8+i;
                
                //set the floor below the surface
                if([key hasPrefix:@"FOOT"]) {
                    [self setPos:storeVertices[index].Position x:x y:y z:-0.1f];
                } else {
                    [self setPos:storeVertices[index].Position x:x y:y z:0.0f];
                }
                
                if([key hasPrefix:@"W"]) {
                    [self setColor:storeVertices[index].Color r:0.182f g:0.182f b:0.182f a:1.0f];
                    [self setColor:storeVertices[index+4].Color r:0.182f g:0.182f b:0.182f a:0.8f];
                    [self setPos:storeVertices[index+4].Position x:x y:y z:0.10f];
                } else if ([key hasPrefix:@"S"]) {
                    [self setColor:storeVertices[index].Color r:0.385f g:0.385f b:0.385f a:1.0f];
                    [self setColor:storeVertices[index+4].Color r:0.385f g:0.385f b:0.385f a:0.7f];
                    [self setPos:storeVertices[index+4].Position x:x y:y z:0.07f];
                } else if([key hasPrefix:@"FOOT"]) {
                    [self setColor:storeVertices[index].Color r:0.382f g:1.382f b:0.382f a:1.0f];
                    [self setColor:storeVertices[index+4].Color r:0.382f g:1.382f b:0.382f a:1.0f];
                    [self setPos:storeVertices[index+4].Position x:x y:y z:0.0f];
                } else {
                    [self setColor:storeVertices[index].Color r:0.921f g:0.146f b:0.139f a:1.0f];
                    [self setColor:storeVertices[index+4].Color r:0.921f g:0.146f b:0.139f a:1.0f];
                    [self setPos:storeVertices[index+4].Position x:x y:y z:0.04f];
                }
            }
            
            int b = k*8;
            int t = b+4;
            
            //four sides
            for(int side=0;side<4;side++) {
                int i = (k*30)+(side*6);
                Indices[i] = b+side;
                Indices[i+1] = side==3 ? b : b+side+1;
                Indices[i+2] = side==3 ? t : t+side+1;
                Indices[i+3] = side==3 ? t : t+side+1;
                Indices[i+4] = t+side;
                Indices[i+5] = b+side;
            }
            
            //top
            int i = (k*30)+24;
            Indices[i] = t;
            Indices[i+1] = t+1;
            Indices[i+2] = t+2;
            Indices[i+3] = t+2;
            Indices[i+4] = t+3;
            Indices[i+5] = t;
        }
        
        
        for(int i=6;i<sizeof(Indices)/sizeof(Indices[0]);i+=6) {
            
                float x=0.0f, y=0.0f, z=0.0f;
                for(int v=i-6;v<i;v++) {
                    x+=storeVertices[Indices[v]].Position[0];
                    y+=storeVertices[Indices[v]].Position[1];
                    z+=storeVertices[Indices[v]].Position[2];
                }
                for(int v=i-6;v<i;v++) {
                    [self setNormal:storeVertices[Indices[v]].Normal  x:x/2 y:y/2  z:z/2];
                }

        }
        
    } //for each aisle
}



-(void) setPos:(float[3]) point x:(float) x  y:(float) y  z:(float) z {
    point[0] = x;
    point[1] = y;
    point[2] = z;
}

-(void) setColor:(float[4]) color r:(float) r  g:(float) g  b:(float) b a:(float) a {
    color[0] = r;
    color[1] = g;
    color[2] = b;
    color[3] = a;
}

-(void) setNormal:(float[3]) normal x:(float) x  y:(float) y  z:(float) z {
    normal[0] = x;
    normal[1] = y;
    normal[2] = z;
}

-(NSDictionary*) readStoreCadFile:(NSString*) filename bounds:(GLKVector4*)bounds
{
    NSMutableDictionary *aisles = [[NSMutableDictionary alloc] init];
    NSError *errorReading;
    NSStringEncoding encoding;
    NSString* mainBundlePath = [[NSBundle mainBundle] resourcePath];
    NSString* path = [mainBundlePath stringByAppendingPathComponent:filename];
    NSString* fileContents = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&errorReading];
    NSMutableArray* rows = [NSMutableArray arrayWithArray:[fileContents componentsSeparatedByString:@"\n"]];
    [rows removeObjectAtIndex:0];
    
    for (NSString *row in rows){
        NSArray* columns = [row componentsSeparatedByString:@","];
        if(columns.count > 1) {
            NSMutableArray* rowVertices = [[NSMutableArray alloc] init];
            GLKVector2 aisleVector[2];
            aisleVector[0] = GLKVector2Make(0.0f, 0.0f);
            aisleVector[1] = GLKVector2Make(0.0f, 0.0f);
            for(int i=1;i<columns.count;i+=2) {
                
                GLfloat point[3];
                for(int j=0;j<2;j++) {
                    NSString* col = [columns objectAtIndex:i+j];
                    NSArray* length = [col componentsSeparatedByString:@"-"];
                    int ft = 0;
                    float inch = 0;
                    if(length.count == 2) {
                        ft = [[(NSString*)[length objectAtIndex:0] stringByReplacingOccurrencesOfString:@"'" withString:@""] intValue]; //= 220'
                        inch = [self parseInch:(NSString*)[length objectAtIndex:1]];
                    } else if(length.count == 1) {
                        ft = 0;
                        inch = [self parseInch:(NSString*)[length objectAtIndex:0]];
                    }
                    float convVal = ft + (inch / 12);
                    
                    
                    
                    if(j==0) {
                        if(convVal > aisleVector[1].x) {
                            aisleVector[1].x = convVal;
                        }
                        if(aisleVector[0].x == 0.0f || aisleVector[0].x > convVal) {
                            aisleVector[0].x = convVal;
                        }
                    } else if(j==1) {
                        if(convVal > aisleVector[1].y) {
                            aisleVector[1].y = convVal;
                        }
                        if(aisleVector[0].y == 0.0f || aisleVector[0].y > convVal) {
                            aisleVector[0].y = convVal;
                        }
                    }
                    
                }
            }//col loop
            
            
            [rowVertices addObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:aisleVector[0].x],
                                    [NSNumber numberWithFloat:aisleVector[0].y],
                                    [NSNumber numberWithFloat:0.0f],nil] ];
            
            [rowVertices addObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:aisleVector[0].x],
                                    [NSNumber numberWithFloat:aisleVector[1].y],
                                    [NSNumber numberWithFloat:0.0f],nil] ];
            
            [rowVertices addObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:aisleVector[1].x],
                                    [NSNumber numberWithFloat:aisleVector[1].y],
                                    [NSNumber numberWithFloat:0.0f],nil] ];
            
            [rowVertices addObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:aisleVector[1].x],
                                    [NSNumber numberWithFloat:aisleVector[0].y],
                                    [NSNumber numberWithFloat:0.0f],nil] ];
            
            [aisles setValue:rowVertices forKey:(NSString*)[columns objectAtIndex:0]];
            
            
            if(bounds->x == 0 || bounds->x > aisleVector[0].x)
                bounds->x = aisleVector[0].x;
            
            if(bounds->y == 0 || bounds->y > aisleVector[0].y)
                bounds->y = aisleVector[0].y;
            
            if(bounds->z < aisleVector[1].x)
                bounds->z = aisleVector[1].x;
            
            if(bounds->w < aisleVector[1].y)
                bounds->w = aisleVector[1].y;
        }
    }// row loop
    return aisles;
}

-(float) parseInch:(NSString*) inch {
    NSArray* inchParts = [inch componentsSeparatedByString:@" "]; //= 6 11/16"
    float frac = 0;
    if(inchParts.count == 2) {
        NSString* fraction = [inchParts objectAtIndex:1];
        fraction = [fraction stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        NSArray* fractionParts = [fraction componentsSeparatedByString:@"/"];
        float dem = [(NSString*)[fractionParts objectAtIndex:1] floatValue];
        float num = [(NSString*)[fractionParts objectAtIndex:0] floatValue];
        frac = num/dem;
    }
    
    return ((float) [(NSString*)[inchParts objectAtIndex:0] floatValue] + frac);
}


@end
