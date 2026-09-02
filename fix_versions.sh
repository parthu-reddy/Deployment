ssh -i /Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key ubuntu@140.245.234.137 "cd 'Food Delivery.nosync/Deployment' && docker compose ps -q | xargs docker inspect -f '{{.Config.Image}}'" | grep hyd.ocir.io | awk -F'/' '{print $4}' | awk -F':' '{
  service=$1;
  tag=$2;
  var=toupper(service) "_TAG";
  gsub("-", "_", var);
  print var "=" tag
}' > .versions
echo "CUSTOMER_SERVICE_TAG=b877a47-85745b9" >> .versions
echo "FOOD_DELIVERY_APP_UI_TAG=a3faa7e-e64b5a4" >> .versions
sort -o .versions .versions
