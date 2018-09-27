install.packages(c('httr', 'jsonlite', 'dplyr', 'lubridate'))

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(data.table)
library(stringr)

# Define keys
app_id = '1702677713160224'
app_secret = 'f484ff69b8f996f807fdbbab899f94cb'

# Define the app
fb_app <- oauth_app(appname = "facebook",
                    key = app_id,
                    secret = app_secret)

# Get OAuth user access token
fb_token <- oauth2.0_token(oauth_endpoints("facebook"),
                           fb_app,
                           scope = c('public_profile','ads_read','ads_management'),
                           type = "application/x-www-form-urlencoded",
                           cache = TRUE)



# Define the API node and query arguments
node <- '/oauth/access_token'
query_args <- list(client_id = app_id,
                   client_secret = app_secret,
                   grant_type = 'client_credentials',
                   redirect_uri = 'http://localhost:1410/')

# GET request to generate the token
response <- GET('https://graph.facebook.com',
                path = node,
                query = query_args)

# Save the token to an object for use

at <- fromJSON(names(fb_token$credentials))$access_token

tomhope<-'act_347596444'


# GET request for UTS facebook page info
response <- GET("https://graph.facebook.com",
                path = paste0('v3.1/',tomhope),
                query = list(access_token = at))

# Check response content
content(response)

path<- paste0('v3.1/',tomhope)

query_args<-list(fields = 'ads.limit(1000){adcreatives{image_url}}',
                 access_token = at)

response<- GET('https://graph.facebook.com',
               path = path,
               query = query_args)

response_parsed0 <- fromJSON(content(response,'text'))

paging<-response_parsed0$ads$paging$'next'
i=0

while(!is.null(paging)){
  i<-i+1
  rp <- GET(paging)
  nam <-paste0('response_parsed',i)
  rp_parsed<-fromJSON(content(rp,'text'))
  assign(nam,rp_parsed)
  paging = rp_parsed$paging$'next'
  }


#
#Getting Tables
#

j=1
jsons = c()

while(exists(paste0('response_parsed',j))){
  jsons = c(jsons,paste0('response_parsed',j))
  j<- j+1
}

#AdID<-response_parsed$ads$data$id
#response_parsed$ads$data$adcreatives$data

response_parsed0$ads$data$id

#
#Setting up the table
#

img_table<-data.frame(AdID = response_parsed0$ads$data$id,image_url = rbindlist(response_parsed0$ads$data$adcreatives$data, fill=TRUE)$image_url,creative_id = rbindlist(response_parsed0$ads$data$adcreatives$data,fill=T)$id)

for (k in 1:length(jsons)){
  img_table<-rbind(img_table,data.frame(AdID = get(jsons[k])$data$id, image_url = rbindlist(get(jsons[k])$data$adcreatives$data,fill=T)$image_url, 
                                        creative_id = rbindlist(get(jsons[k])$data$adcreatives$data,fill=T)$id))
}

img_table$image_url <- (as.character(img_table$image_url))
img_table$AdID <- as.character(img_table$AdID)
img_table$creative_id <-as.character(img_table$creative_id)

img_table<-img_table[complete.cases(img_table),]

img_table<-transform(img_table, image_id = match(image_url,unique(image_url)))

dt<-as.character(Sys.Date())

dir.exists(sprintf('./data/th_images/%s',dt))
dir.create(sprintf('./data/th_images/%s',dt))

img_path<-sprintf('./data/th_images/%s',dt)

write.csv(img_table, file=sprintf('%s/img_table.csv',img_path))

img_uniques <- img_table[!duplicated(img_table['image_url']),]


#
#Downloading the Images
#

filetype<-c('jpg','png')
str_extract(filetype)

for (i in 1:nrow(img_uniques)){
  tryCatch(
    download.file(img_uniques$image_url[i], destfile = paste0(img_path,'/',img_uniques$image_id[i],'.',
                                                            str_extract(img_uniques$image_url[i],c('jpg','png'))[complete.cases(str_extract(img_uniques$image_url[i],c('jpg','png')))]), 
                         method = 'curl', quiet = FALSE, mode = "w",
              cacheOK = TRUE), error=function(e){})
} 

#MUST DO THIS TO GET FILE NUMBERS RIGHT
#To rename images, in bash: 
#$ for i in *.jpg ; do
#     mv $i `printf '%04d' ${i%.jpg}`.jpg
# done
