#################################################
#### A FUNCTION TO GENERATE AN ARENA PROFILE 
#################################################
Arena <- function(h=3.5, radius=30){
  h <- 3.5 ##millimeters (height of arena from floor to ceiling)

  ####WITH THIS DESIGN THE ARENA CANNOT HAVE A RADIUS
  ####LESS THAN 30 mm....
  radius <- 30 ## arena radius in millimeters
  #################
  
  theta <- 11*pi/180  ## slope of vertical wall of arena 
  ##11 degrees converted to radians 
  I = h*pi/(4*tan(theta))
  Xmax <- h/(2*tan(theta)) + I
  
  #Straw commented on typos in the equations!
  # x = h/(2*tan(theta)) + I
  
  x <- seq(0, 2*I, 0.1)

  x1 <- x[which(x>=0 & x<=I)]
  y1 <- h*(1-cos((pi*x1)/(2*I)))/2

  ##For i<x<=Xmax
  x2 <- x[which(x>=I & x<=Xmax)]
  y2 <- tan(theta)*(x2-I) + (h/2)

  ## DEFINE AN EMPTY PLOT
  plot(x1, y1, type='n', xlim=c(0, radius), ylim=c(0, radius + 10), axes=FALSE, xlab="", ylab="")

  #DRAW THE PIECES OF THE PROFILE
  segments(0, 0, (radius-Xmax), 0, lwd=3)
  
  lines(x1+radius-Xmax, y1, type='l', lwd=3)

  lines(x2+radius-Xmax, y2, lwd=3)
  
  segments(radius, tan(theta)*(Xmax-I) + (h/2), radius, 0, lwd=3)
  
  # A LABEL WITH INFO REGARDING THE PROFILE
  mtext(paste("radius=", radius, " ", "h=", h))
}
