#' Event Counting
#'
#'
#'This function creates a table with the number of event for a given species.
#'Input needed:
#'    - KORA.Photo.Output = "Nameofcsv.csv" KORA ouput with lynx or any other species observed (All have been IDed)
#'    Important Note:
#'    - The csv must be in the folder of the used RStudio Project
#'    - Date in the csv must be in '%Y-%m-%d %H:%M:%S' (Standard KORA data and R format)
#'
#' @param # Author: Luc Le Grand
#' @return
#' @export
EvCountR<-function(
  Table_Object,
  Event_length){

  # ---- Import Data ####

  # Import KORA Photo data
  M.Table<-data.table::as.data.table(Table_Object)
  M.Table<-M.Table[,c("TIME","ID","x","y")]

  # ---- Arange Master Table ####

  #Time/Date info
  M.Table$TIME <- as.POSIXct(M.Table$TIME, format= '%Y-%m-%d %H:%M:%S')
  M.Table$XY<-paste(M.Table$x,M.Table$y, sep=";")

  # ---- Create output table ####
  Table<-data.table::data.table(ID=unique(M.Table$ID), Event=0)

  # Count number of events/N pictures

  for(i in 1:length(Table$ID)){
    df<-data.table::data.table(timestamp = M.Table[M.Table$ID == Table[i, ID],TIME],
                               XY =M.Table[M.Table$ID == Table[i, ID],XY])
    df<-df[, .(
      startTime = timestamp[1L],
      endTime = timestamp[.N],
      sensorCount = .N,
      duration = difftime(timestamp[.N], timestamp[1L], units = "mins")
    ),
    by = .(XY,
           cumsum(difftime(timestamp, data.table::shift(timestamp, fill = timestamp[1L]), "mins") > Event_length))]

    Table[i, "Event"]<-length(df$cumsum)
    Table[i,"N pictures"]<-sum(df$sensorCount)
    Table[i,"N site"]<-length(unique(df$XY))
  }

  # creates the "Total" row
  Table<-rbind(Table,data.table::data.table(ID = "Total", t(colSums(Table[, -1]))))

  # Total site should be the total of unique site
  Table[Table$ID=="Total","N site"]<-length(unique(M.Table[,XY]))

  # ---- Print ouput ####
  return(Table)
  #cat("\n")
  #cat("Warning:\n")
  #cat("Total N site is equal to the total number of UNIQUE site where the species has been seen")

}
