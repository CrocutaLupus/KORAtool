#' KORAmapsex
#'
#' @param KORA.Photo.Output
#' @param species
#' @param Buffer.map
#' @param Zoom.map
#' @param IDremove
#' @param Start
#' @param Stop
#' @param Buffer.polygon
#' @param Pattern
#' @param Buffer.label
#' @param Name.Map
#' @param Refarea
#' @param Red.point.ID
#' @param Sexremove
#'
#' @return
#' @export
#'
#' @examples
KORAmapsex<-function(
  KORA.Photo.Output,
  species,
  Buffer.map,
  Zoom.map,
  IDremove,
  Start,
  Stop,
  Buffer.label,
  Pattern,
  Name.Map,
  Refarea,
  Red.point.ID,
  Sexremove
  
){
  
  # ---------- Default values: ####
  if(!exists("KORA.Photo.Output")){warning("KORA.Photo.Output not provided")}
  if(!exists("species")){warning("species not provided")}
  if(!exists("Buffer.map")){warning("Buffer.map not provided. Default = 0.01"); Buffer.map<-0.01}
  if(!exists("Start")){warning("Start date not provided")}
  if(!exists("Stop")){warning("Stop date not provided")}
  if(!exists("Zoom.map")){warning("Zoom.map not provided. Default = 14"); Zoom.map<-13}
  if(!exists("Buffer.label")){warning("Buffer.polygon not provided. Default = 2000m"); Buffer.label<-2000}
  if(!exists("Red.point.ID")){warning("Red.point.ID not provided. Default = NO_red_point"); Red.point.ID<-"NO_red_point"}
  if(!exists("Sexremove")){warning("Sexremove not provided. Default = none removed"); Sexremove<-""}
  # ------------------- Import Data ####
  
  table<-KORA.Photo.Output[, c("animal_species","x","y", "exposure_date", "exposure_time","id_individual","Sex","Juv")]
 
  #Sites
  table$XY<-paste(table$x,table$y, sep=";")
  
  Sites<-data.table::data.table(x=as.numeric(stringr::str_split_fixed(unique(table$XY), ";", 2)[,1]),
                                y=as.numeric(stringr::str_split_fixed(unique(table$XY), ";", 2)[,2]))
  
  #Create TIME variable (date and time in correct format)
  table$TIME<-as.POSIXct(paste(table$exposure_date,table$exposure_time, sep=" "),
                         format= "%Y-%m-%d %H:%M:%S")
  #Subset Date
  table<-table[table$TIME>as.POSIXct(Start,format= "%Y-%m-%d %H:%M:%S") &
                 table$TIME<as.POSIXct(Stop,format= "%Y-%m-%d %H:%M:%S"),]
  #Keep only used variables
  table<-table[,c("animal_species","XY","x","y","TIME","id_individual","Sex","Juv")]
  
  # Remove unwantex sex
  table<-table[!(table$Sex %in% Sexremove),]
  
  # ------------------- Map 
  
  # ------ Projection : 
  #Projection to be used for the map (CH1903 / LV03):
  #Warnings OK
  suppressWarnings(CRS<- sp::CRS("+init=epsg:21781"))
  
  # ------ Study Area 
  
  # --- Import shapefile Study area Polygon
  suppressWarnings(Rcompartment <- raster::shapefile("MAP_Data/Reference_areas_all_new2022.shp"))
  Rcompartment<-Rcompartment[Refarea,]

  #Compute Boundary Box (BB)
  study_area.origin<-sp::bbox(Rcompartment)
  study_area<-study_area.origin
  
  #Add x% around the BBox to have some extra map area
  
  study_area[1,1]<-study_area[1,1]-round(study_area[1,1]*Buffer.map) #x min
  study_area[2,1]<-study_area[2,1]-round(study_area[2,1]*2*Buffer.map) #y min
  study_area[1,2]<-study_area[1,2]+round(study_area[1,2]*Buffer.map) #x max
  study_area[2,2]<-study_area[2,2]+round(study_area[2,2]*Buffer.map) #y max
  
  study_area<-rgeos::readWKT(paste("POLYGON((",
                                   study_area[1,1]," ",study_area[2,1],",",
                                   study_area[1,1]," ",study_area[2,2],",",
                                   study_area[1,2]," ",study_area[2,2],",",
                                   study_area[1,2]," ",study_area[2,1],",",
                                   study_area[1,1]," ",study_area[2,1],"))",sep=""),p4s= CRS)
  # ------ Open Source Map####
  
  #study area BBox in lat long
  study_area_lat_long <- sp::spTransform(study_area, sp::CRS("+init=epsg:4326"))
  
  LAT1 = study_area_lat_long@bbox[2,1] ; LAT2 = study_area_lat_long@bbox[2,2]
  LON1 = study_area_lat_long@bbox[1,1] ; LON2 = study_area_lat_long@bbox[1,2]
  
  #Get the map
  #warnings OK
  suppressWarnings(map <- OpenStreetMap::openmap(c(LAT2,LON1), c(LAT1,LON2), zoom = Zoom.map, #can be replaced by NULL
                                                 type = c("bing")[1],
                                                 mergeTiles = TRUE))
  
  #Correct projection
  #warnings OK
  suppressWarnings(map <- OpenStreetMap::openproj(map, projection = "+init=epsg:21781"))
  
  # ------ Build map ####
  
  # --- Open Source Map in ggplot:####
  map <- OpenStreetMap::autoplot.OpenStreetMap(map)+
    ggplot2::theme(axis.title=ggplot2::element_blank(),
                   axis.text=ggplot2::element_blank(),
                   axis.ticks=ggplot2::element_blank(),
                   panel.border = ggplot2::element_rect(colour = "white", fill=NA, size=15))
  
  # --- Add shapefile Study area Polygon
  map<-map+ggplot2::geom_polygon(data = Rcompartment@polygons[[1]], ggplot2::aes(x=long, y=lat,group = group),
                               colour="darkblue", fill=NA, alpha=1, lwd=1.1)+
  # --- Add Sites:####
  ggplot2::geom_point(data=Sites,ggplot2::aes(x,y), col="white", pch=19,size=5)+
  ggplot2::geom_point(data=Sites,ggplot2::aes(x,y),col="black", pch=1,size=5)
  
  # --- Get city names for the map ####
  #Official directory of towns and cities (CH)
  Cities <- fread("MAP_Data/cities_LV03.csv",encoding="Latin-1")
  #as spatial
  Cities <- sp::SpatialPointsDataFrame(coords = Cities[,c("x","y")], data = Cities,
                                     proj4string = CRS)

  #crop cities in study area
  Cities <-raster::crop(Cities,study_area)
  Cities <-data.table::as.data.table(Cities) 


  # --- Add Cities dots to map:####
  map<-map+ggplot2::geom_point(data=Cities,ggplot2::aes(x,y), col="#D55E00", pch=19,size=1)+
         ggrepel::geom_text_repel(data=Cities,ggplot2::aes(x,y,label=Ort), color ="white")
  
  
 # --- Add Scale: ####
  
  # distance on x axes:
  dist.scale<-plyr::round_any(round(((study_area@bbox[1,2]-study_area@bbox[1,1])/1000)/4), 10, f = ceiling)
  
  # scale thickness:
  s.thick<-(0.01*(study_area@bbox[2,2]-study_area@bbox[2,1]))
  
  # scale black rectangle
  xleft<-study_area@bbox[1,1]+((study_area.origin[1,1]-study_area@bbox[1,1])/2)#left
  xright<-xleft+dist.scale*1000#right
  ybottom<-study_area@bbox[2,1]+((study_area.origin[2,1]-study_area@bbox[2,1])/2)
  ytop<-ybottom+1*s.thick#top
  
  map<-map+
    ggplot2::geom_rect(mapping=ggplot2::aes(xmin=xleft, xmax=xright, ymin=ybottom, ymax=ytop),
                       fill=c("black"),
                       inherit.aes = FALSE)+
    ggplot2::geom_text(x=xright+(2/5)*dist.scale*1000, y=ytop, label=paste(dist.scale,"Km",sep=" "), cex=10, color ="black")
  
  # --- Add the polygons and labels: ####
  
  # -- Create Table
  ID.names<-table[table$animal_species==species, c("id_individual","animal_species","Sex","Juv")]
  ID.names<-unique(ID.names)
  
  # -- Indicate colors
  
  #All black as default
  ID.names$col<-"#000000"
  #Males in blue
  ID.names[ID.names$Sex=="male","col"]<-"#0072B2"
  #Females in pink
  ID.names[ID.names$Sex=="female","col"]<-"#CC79A7"
  
  names(ID.names)[1]<-"ID"
  
  # -- remove unwanted ID
  if(exists("IDremove")){ID.names<-ID.names[ID.names$ID!=IDremove,]}
  
  # -- remove Juv polygons
  
  ID.names<-ID.names[ID.names$Juv!="Juv" | is.na(ID.names$Juv),]
  
  # -- Compute the polygons
  sp_poly.all <- vector(mode = "list")
  
  suppressWarnings(
    
    for(i in 1:length(ID.names$ID)){
      dat <- table[table$id_individual==ID.names[i,ID],c("x","y")] #if in github ID should be in "ID"
      
      #polygon around outer points
      coords<-as.data.frame(concaveman::concaveman(as.matrix(dat)))
      
      sp_poly <- sp::SpatialPolygons(list(sp::Polygons(list(sp::Polygon(coords)), ID=ID.names[i,"ID"])))
      raster::crs(sp_poly)<-CRS
      
      if(ID.names[i,Sex]=="male"){
      Buffer.polygon<-1800}
      if(ID.names[i,Sex]=="female"){
      Buffer.polygon<-1400}
      if(ID.names[i,Sex]=="unknown"){
      Buffer.polygon<-1000}
      
      sp_poly<-rgeos::gBuffer(sp_poly,width=Buffer.polygon)
      raster::crs(sp_poly)<-CRS
      sp_poly.all[i]<-sp_poly
      
    }
  )
  
  # -- Data labels
  
  data_labels<-data.frame()
  for(i in 1:length(ID.names$ID)){
    
    #Label origin to be closest from the side
    diff.left<-min(sp_poly.all[[i]]@polygons[[1]]@Polygons[[1]]@coords[,1])-study_area.origin[1,1]
    diff.right<-study_area.origin[1,2]-max(sp_poly.all[[i]]@polygons[[1]]@Polygons[[1]]@coords[,1])
    
    if(diff.left>diff.right){ #if label should be on the right
      
      df<-data.frame(sp_poly.all[[i]]@polygons[[1]]@Polygons[[1]]@coords)
      data_labels[i, "lon"]<-df[which.max(df$x),1]
      data_labels[i, "lat"]<-df[which.max(df$x),2]
      data_labels[i, "side"]<-"right"
      
    }else{ #label should be on the left
      
      df<-data.frame(sp_poly.all[[i]]@polygons[[1]]@Polygons[[1]]@coords)
      data_labels[i, "lon"]<-df[which.min(df$x),1]
      data_labels[i, "lat"]<-df[which.min(df$x),2]
      data_labels[i, "side"]<-"left"
    }
    
    #Remove part of ID name which is repeated (ex."JS2018FS")
    data_labels[i, "ID"]<- stringr::str_remove(ID.names[i,ID], pattern =   Pattern) 
    data_labels[i, "col.ID"]<- ID.names[i,col]
  }
  
  # -- remove unwanted ID
  if(exists("IDremove")){data_labels<-data_labels[data_labels$ID!=IDremove,]}
  
  # -- Add JUV to juvenile ID
  
  data_labels=data_labels
  
  # -- Add to the map
  
  for(i in 1:length(ID.names$ID)){
    
    map<-map+
      ggplot2::geom_polygon(data = sp_poly.all[[i]], ggplot2::aes(x=long, y=lat, group = group),
                            colour=ID.names[i,col], fill=NA, alpha=1, lwd=1.5)
  }
  
  # -- check if label starts are too close to each other:
  
  # compute distance:
  pts.label<-data_labels[,c("ID","lon","lat")]
  pts.label <- sf::st_as_sf(pts.label, crs = CRS, coords = c("lon", "lat"))
  
  Mat.label<-matrix(as.numeric(sf::st_distance(pts.label, pts.label)),
                       nrow = length(data_labels$ID), 
                       ncol = length(data_labels$ID))
  
  # Subset label with distance < 2000 m
  
  wich.label<-as.data.table(which(Mat.label < 2000 , arr.ind=TRUE))
  wich.label<-wich.label[wich.label$row!=wich.label$col,]
  
  #Continue if necessary:
  if(nrow(wich.label)>0){
    
    # Select every second line as matrix present the distance twice
    ind <- seq(1, nrow(wich.label), by=2)
    wich.label<-wich.label[ind, ]
    
    # Change label coordinates 
    
    for(i in 1: nrow(wich.label)){
      
      df<-data.frame(sp_poly.all[[wich.label[i,col]]]@polygons[[1]]@Polygons[[1]]@coords)
      data_labels[wich.label[i,col], "lon"]<-df[which.min(df$y),1]
      data_labels[wich.label[i,col], "lat"]<-df[which.min(df$y),2]
      
    }
      
  }
  
  # -- Add the labels:
  
  #Add label left side
  map<-map+
    ggrepel::geom_text_repel(data = data_labels[data_labels$side=="left",], ggplot2::aes(lon, lat, label = ID),
                              colour = data_labels[data_labels$side=="left","col.ID"],cex=4,
                              segment.size=0.5,
                              force = 20,
                              xlim = c(study_area@bbox[1,1], study_area.origin[1,1]-Buffer.label), ylim = c(study_area.origin[2,1],study_area.origin[2,2]),
                              bg.color = "white",
                              bg.r = 0.25)
  #Add label right side
  map<-map+
    ggrepel::geom_text_repel(data = data_labels[data_labels$side=="right",], ggplot2::aes(lon, lat, label = ID),
                              colour = data_labels[data_labels$side=="right","col.ID"],cex=4,
                              segment.size=0.5,
                              force = 20,
                              xlim = c(study_area.origin[1,2]+Buffer.label,study_area@bbox[1,2]), ylim = c(study_area.origin[2,1],study_area.origin[2,2]),
                              bg.color = "white",
                              bg.r = 0.25)
  
  
  # --- Add points U red:####
  map<-map+ggplot2::geom_point(data=table[table$animal_species==species &
                                            table$id_individual==Red.point.ID,],
                               ggplot2::aes(x=x,y=y),
                               col="red", pch=19, cex=1.5)
  
    # --- Add points orange Juv:####
  
  
  map<-map+ggplot2::geom_point(data=table[table$animal_species==species & 
                                            table$Juv=="Juv",],
                               ggplot2::aes(x=x,y=y),
                               col="#009E73", pch=19, cex=1.5)
  
  # --- Add points black:####
  map<-map+ggplot2::geom_point(data=table[table$animal_species==species & 
                                          table$id_individual!=Red.point.ID,],
                               ggplot2::aes(x=x,y=y),
                               col="black", pch=19, cex=1.5)
  

  
  # ------------------- Export the plot:####
  
  
  if(!exists("Name.Map")){
    
    ggplot2::ggsave(paste("Map_",
                          Sys.Date(),"_",
                          sprintf("%02d", data.table::hour(Sys.time())),
                          data.table::minute(Sys.time()),".jpeg",sep=""),plot=map,
                    units = "cm",
                    width = 24,
                    height = 20)
    
  }else{
    
    ggplot2::ggsave(paste(Name.Map,".jpeg",sep=""),plot=map,
                    units = "cm",
                    width = 24,
                    height = 20)
    
  }

  
  
}
