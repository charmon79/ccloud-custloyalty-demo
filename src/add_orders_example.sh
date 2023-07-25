#!/bin/bash

# Import additional orders to demonstrate real-time processing
mongoimport --uri="mongodb+srv://user:password@my.cluster.mongodb.net/" \
    -d coffeeshop \
    -c orders \
    --file="additional-orders.json" --jsonArray
