# WistiaTron Raspberry Pi Image Builder

## Generate the image

```bash
./build-image.sh
```             

## Find the box IP

```bash
ping -c 1 google.com &> /dev/null ; arp -a | grep b8:27
```

## Copy your public key

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub pi@10.10.10.244
```                                             

Enter "raspberry" for password when prompted.

## Log into the new box

```bash
ssh -A pi@10.10.10.244
```