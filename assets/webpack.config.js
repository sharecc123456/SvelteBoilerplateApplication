const path = require("path");
const glob = require("glob");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CopyWebpackPlugin = require("copy-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const WarningsToErrorsPlugin = require("warnings-to-errors-webpack-plugin");

module.exports = (env, options) => {
  const devMode = options.mode !== "production";

  return {
    watchOptions: {
      poll: 1000,
    },
    optimization: {
      minimize: devMode ? undefined : true,
      minimizer: [new TerserPlugin()],
    },
    entry: {
      app: glob.sync("./vendor/**/*.js").concat(["./js/app.js"]),
      stormwind: glob.sync("./vendor/**/*.js").concat(["./js/stormwind.js"]),
      ironforge: glob.sync("./vendor/**/*.js").concat(["./js/ironforge.js"]),
    },
    output: {
      filename: "[name].js",
      chunkFilename: "[name].[id].js",
      path: path.resolve(__dirname, "../priv/static/js"),
      publicPath: "/js/",
    },
    resolve: {
      alias: {
        svelte: path.resolve("node_modules", "svelte"),
        BoilerplateAPI: path.resolve(__dirname, "/js/api/"),
        IAC: path.resolve(__dirname, "/js/iac/"),
        Helpers: path.resolve(__dirname, "/js/helpers/"),
        Components: path.resolve(__dirname, "/js/ui/components"),
        Atomic: path.resolve(__dirname, "/js/ui/atomic"),
        Modals: path.resolve(__dirname, "/js/ui/modals"),
      },
      extensions: [".mjs", ".js", ".svelte"],
      mainFields: ["svelte", "browser", "module", "main"],
      modules: ["node_modules"],
    },
    devtool: devMode ? "eval-source-map" : "source-map",
    module: {
      rules: [
        {
          test: /\.m?js$/,
          include: /node_modules/,
          type: "javascript/auto",
          resolve: {
            fullySpecified: false,
          },
        },
        {
          test: /\.(html|svelte)$/,
          exclude: path.resolve(__dirname, "/node_modules"),
          use: {
            loader: "svelte-loader",
            options: {
              emitCss: true,
            },
          },
        },
        {
          test: /\.js$/,
          exclude: [
            /node_modules/,
            /js\/api/,
            /js\/mock_api/,
            /js\/iac/,
            /js\/helpers/,
          ],
          use: {
            loader: "babel-loader",
          },
        },
        {
          test: /\.[s]?css$/,
          use: [
            MiniCssExtractPlugin.loader,
            "css-loader",
            {
              loader: "sass-loader",
              options: {
                implementation: require("sass"),
              },
            },
          ],
        },
      ],
    },
    plugins: [
      new MiniCssExtractPlugin({ filename: "../css/[name].css" }),
      new CopyWebpackPlugin([{ from: "static/", to: "../" }]),
      new WarningsToErrorsPlugin(),
    ],
  };
};
