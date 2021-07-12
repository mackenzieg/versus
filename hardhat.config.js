/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('@nomiclabs/hardhat-waffle');

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.0",
        settings: {
          optimizer: {
          enabled: true,
          runs: 1000
          }
        }
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
          enabled: true,
          runs: 1000
          }
        }
      },
      {
        version: "0.6.2",
        settings: {
          optimizer: {
          enabled: true,
          runs: 1000
          }
        }
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
          enabled: true,
          runs: 1000
          }
        }
      },
      {
        version: "0.5.0",
        settings: {
          optimizer: {
          enabled: true,
          runs: 1000
          }
        }
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
          enabled: true,
          runs: 1000
          }
        }
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
          enabled: true,
          runs: 1000
          }
        }
      },
      {
        version: "0.4.18",
        settings: {
          optimizer: {
          enabled: true,
          runs: 1000
          }
        }
      },
    ]
  }
};
