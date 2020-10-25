![alt text](https://github.com/flexera/aws-control-tower/blob/main/aws-control-tower.png?raw=true)

# Flexera Optima Integration with AWS Control Tower

This repository provides all assets used to integrate Flexera Optima with AWS Control Tower.

## Integration Guide

Follow the steps in the  [Flexera Optima Integration Guide](https://linktodguide.) to complete the integration.

```command line integration.
aws cloudformation create-stack-set \
    --stack-set-name flexera-optima \
    --template-body file://flexeraOptimaAwsControlTower.yaml \
    --description "Flexera Optima Integration"
```

## Usage



## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.


## License
[MIT](https://choosealicense.com/licenses/mit/)
