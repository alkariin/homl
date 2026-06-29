package shared

import (
	"io/ioutil"
	"os"
)

func readJsonFile(filePath string) ([]byte, error) {
	jsonFile, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer jsonFile.Close()
	byteValue, _ := ioutil.ReadAll(jsonFile)

	return byteValue, nil
}

func GetConstants() ([]byte, error) {
	byteValue, err := readJsonFile("constants.json")
	if err != nil {
		return nil, err
	}
	return byteValue, nil
}
